local M = {}

local query = require('possession.query')
local utils = require('possession.utils')

local function ts_parse_query(lang, ts_query)
    if vim.tbl_get(vim, 'treesitter', 'query', 'parse') then
        return vim.treesitter.query.parse(lang, ts_query)
    else
        return vim.treesitter.parse_query(lang, ts_query)
    end
end

-- FIXME: This seems hacky as hell and will most likely break some day...
-- Get the lua parser for given buffer and replace its injection query
-- with one that will highlight vimscript inside the string stored in
-- the`vimscript` variable.
local function patch_treesitter_injections(buf)
    local parser = vim.treesitter.get_parser(buf, 'lua')
    local new_query = ts_parse_query(
        'lua',
        [[
        (assignment_statement
            (variable_list (identifier) @_vimscript_identifier)
            (expression_list (string content: _ @vim)
            (#eq? @_vimscript_identifier "vimscript")))
    ]]
    )
    parser._injection_query = new_query
end

---@class possession.EchoSessionsOpts
---@field sessions? table[]
---@field vimscript? boolean include vimscript in the output
---@field user_data? boolean include user_data in the output

--- Print a list of sessions as Vim message
---@param opts? possession.EchoSessionsOpts
function M.echo_sessions(opts)
    opts = vim.tbl_extend('force', {
        sessions = nil,
        vimscript = false,
        user_data = true,
    }, opts or {})

    local sessions = opts.sessions or query.as_list()

    local chunks = {}
    local add = function(parts)
        local as_chunk = function(part)
            return type(part) == 'string' and { part } or part
        end
        vim.list_extend(chunks, vim.tbl_map(as_chunk, parts))
    end

    for i, data in ipairs(sessions) do
        if i ~= 1 then
            add { '\n' }
        end

        add { { 'Name: ', 'Title' }, data.name, '\n' }

        if data.file then
            add { { 'File: ', 'Title' }, data.file, '\n' }
        end

        add { { 'Cwd: ', 'Title' }, data.cwd, '\n' }

        if opts.user_data then
            local s = vim.inspect(data.user_data, { indent = '    ' })
            local lines = utils.split_lines(s)
            add { { 'User data: ', 'Title' }, '\n' }
            for l = 2, #lines do
                add { lines[l], '\n' }
            end
        end

        if opts.vimscript then
            -- Does not really make sense to list vimscript, at least join lines.
            local line = data.vimscript:gsub('\n', '\\n')
            add { { 'Vimscript: ', 'Title' }, line, '\n' }
        end
    end

    vim.api.nvim_echo(chunks, false, {})
end

--- Display session data in given buffer.
--- Data may optionally contain "file" key with path to session file.
---@param data table
---@param buf integer
function M.in_buffer(data, buf)
    -- (a bit hacky) way to easily get syntax highlighting - just format everything
    -- as valid Lua code and set filetype.

    buf = buf or vim.api.nvim_get_current_buf()

    local lines = {}

    table.insert(lines, 'name = ' .. vim.inspect(data.name))
    table.insert(lines, 'file = ' .. vim.inspect(data.file))
    table.insert(lines, 'cwd = ' .. vim.inspect(data.cwd))
    table.insert(lines, '')

    local user_data = vim.inspect(data.user_data, { indent = '    ' })
    user_data = utils.split_lines(user_data)
    table.insert(lines, 'user_data = ' .. user_data[1])
    vim.list_extend(lines, user_data, 2)

    local plugin_data = vim.inspect(data.plugins, { indent = '    ' })
    plugin_data = utils.split_lines(plugin_data)
    table.insert(lines, 'plugin_data = ' .. plugin_data[1])
    vim.list_extend(lines, plugin_data, 2)

    table.insert(lines, '')
    table.insert(lines, 'vimscript = [[')
    local vimscript = utils.split_lines(data.vimscript, true)
    vimscript = vim.tbl_map(function(line)
        return '    ' .. line
    end, vimscript)
    vim.list_extend(lines, vimscript)
    table.insert(lines, ']]')

    vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')

    -- Try to add vimscript injections
    local ok = pcall(patch_treesitter_injections, buf)
    if not ok then
        utils.warn('Adding treesitter injections in preview window failed')
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return M
