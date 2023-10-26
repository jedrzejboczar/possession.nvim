local M = {}

local Path = require('plenary.path')
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

local function with_match(pattern, fn)
    return function(line)
        local m = line:match(pattern)
        if m then
            fn(m)
            return true
        end
    end
end

---@class possession.MkSessionInfo
---@field buffers string[]
---@field cwd string?
---@field tab_cwd string[]
---@field win_cwd string[]

--- Parse vimscript output of mksession to get information about buffers/workdirs
---@param vimscript string
---@return possession.MkSessionInfo
function M.parse_mksession(vimscript)
    local info = { buffers = {}, cwd = nil, tab_cwd = {}, win_cwd = {} }

    local parsers = {
        with_match('^badd %S+ (.*)$', function(m)
            -- Paths in mksession are relative if they're under cwd, so convert to absolute
            local path = Path:new(vim.fn.expand(m))
            if not path:is_absolute() and info.cwd then
                path = Path:new(info.cwd) / path
            end
            info.buffers[path:absolute()] = true
        end),
        with_match('^cd (.*)$', function(m)
            if info.cwd then
                utils.warn('Found multiple "cd" in mksession vimscript')
            end
            info.cwd = vim.fn.expand(m)
        end),
        with_match('| tcd (.*) | endif$', function(m)
            info.tab_cwd[vim.fn.expand(m)] = true
        end),
        with_match('^lcd (.*)$', function(m)
            info.win_cwd[vim.fn.expand(m)] = true
        end),
    }

    for line in vim.gsplit(vimscript, '\n', { plain = true, trimempty = true }) do
        for _, parser in ipairs(parsers) do
            if parser(line) then
                break
            end
        end
    end

    return {
        buffers = vim.tbl_keys(info.buffers),
        cwd = info.cwd,
        tab_cwd = vim.tbl_keys(info.tab_cwd),
        win_cwd = vim.tbl_keys(info.win_cwd),
    }
end

---@class possession.EchoSessionsOpts
---@field sessions? table[]
---@field vimscript? boolean include vimscript in the output
---@field user_data? boolean include user_data in the output
---@field buffers? boolean include buffers from parsed vimscript
---@field buffers_short? boolean show buffer paths normalized and relative to session cwd
---@field tab_cwd? boolean include tab cwds from parsed vimscript

--- Print a list of sessions as Vim message
---@param opts? possession.EchoSessionsOpts
function M.echo_sessions(opts)
    opts = vim.tbl_extend('force', {
        sessions = nil,
        vimscript = false,
        user_data = true,
    }, opts or {})

    local sessions = opts.sessions or query.as_list()

    local info = {}
    if opts.buffers or opts.tab_cwd then
        for _, data in ipairs(sessions) do
            info[data] = M.parse_mksession(data.vimscript)
        end
    end

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

        if opts.tab_cwd then
            add { { 'Tab cwds:', 'Title' }, '\n' }
            for _, cwd in ipairs(info[data].tab_cwd) do
                add { '  ', cwd, '\n' }
            end
        end

        if opts.buffers then
            add { { 'Buffers:', 'Title' }, '\n' }
            local paths = {}
            for _, buf in ipairs(info[data].buffers) do
                local path = opts.buffers_short and utils.relative_path(buf, data.cwd) or Path:new(buf):absolute()
                table.insert(paths, path)
            end
            table.sort(paths)
            for _, path in ipairs(paths) do
                add { '  ', path, '\n' }
            end
        end

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

---@param data table
---@param buf integer
local function in_buffer_raw(data, buf)
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

local function buf_display_builder(buf)
    local lines = {}
    local highlights = {}
    return {
        ---@param parts (string|{ [1]: string, [2]: string })[] line strings or tuples { string, hl_group }
        line = function(parts)
            local col = 0
            local line_parts = {}
            for _, part in ipairs(parts) do
                local hl
                if type(part) == 'table' then
                    part, hl = unpack(part)
                end
                local len = vim.fn.strdisplaywidth(part)
                if hl then
                    local srow, scol, erow, ecol = #lines, col, #lines, col + len
                    table.insert(highlights, { srow, scol, erow, ecol, hl })
                end
                col = col + len
                table.insert(line_parts, part)
            end
            table.insert(lines, table.concat(line_parts))
        end,
        render = function()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

            local ns = vim.api.nvim_create_namespace('possession.display')
            for _, hl in ipairs(highlights) do
                local srow, scol, erow, ecol, hl_group = unpack(hl)
                vim.api.nvim_buf_set_extmark(buf, ns, srow, scol, {
                    end_row = erow,
                    end_col = ecol,
                    hl_group = hl_group,
                })
            end
        end,
    }
end

local function in_buffer_pretty(data, buf)
    buf = buf or vim.api.nvim_get_current_buf()

    local info = M.parse_mksession(data.vimscript)

    local builder = buf_display_builder(buf)

    local normalize = function(s)
        return vim.fn.fnamemodify(s, ':~')
    end

    local function paths_list(paths)
        paths = vim.tbl_map(normalize, paths)
        local common = #paths <= 1 and '' or utils.find_common_prefix(paths)

        -- remove until last separator
        local sep = '/' -- \ for windows?
        local sep_offset = common:reverse():find(sep) or 0
        common = common:sub(1, #common - sep_offset)

        for _, path in ipairs(paths) do
            builder.line { { path:sub(1, #common), 'Comment' }, path:sub(#common + 1) }
        end
    end

    builder.line { { 'Name: ', 'Title' }, data.name }
    builder.line { { 'File: ', 'Title' }, normalize(data.file) }
    builder.line { { 'Cwd: ', 'Title' }, normalize(data.cwd) }
    builder.line {}

    if #info.tab_cwd > 0 then
        builder.line { { 'Tab cwds:', 'Title' } }
        table.sort(info.tab_cwd)
        paths_list(info.tab_cwd)
        builder.line {}
    end

    builder.line { { 'Buffers:', 'Title' } }
    paths_list(info.buffers)

    if vim.tbl_count(data.user_data) > 0 then
        builder.line {}
        builder.line { { 'User data:', 'Title' } }
        local user_data = vim.inspect(data.user_data, { indent = '  ' })
        for _, line in ipairs(utils.split_lines(user_data)) do
            builder.line { line }
        end
    end

    builder.line {}
    builder.line { { 'Plugin data:', 'Title' } }
    local plugin_data = vim.inspect(data.plugins, { indent = '  ' })
    for _, line in ipairs(utils.split_lines(plugin_data)) do
        builder.line { line }
    end

    builder.render()
end

--- Display session data in given buffer.
--- Data may optionally contain "file" key with path to session file.
---@param data table
---@param buf integer
---@param mode? 'raw'|'pretty' defaults to 'raw'
function M.in_buffer(data, buf, mode)
    mode = mode or 'raw'
    if mode == 'raw' then
        in_buffer_raw(data, buf)
    elseif mode == 'pretty' then
        in_buffer_pretty(data, buf)
    else
        assert(false, mode)
    end
end

return M
