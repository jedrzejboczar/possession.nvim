local M = {}

local utils = require('possession.utils')

local function split_lines(s, trimempty)
    return vim.split(s, '\n', { plain = true, trimempty = trimempty })
end

-- FIXME: This seems hacky as hell and will most likely break some day...
-- Get the lua parser for given buffer and replace its injection query
-- with one that will highlight vimscript inside the string stored in
-- the`vimscript` variable.
local function patch_treesitter_injections(buf)
    local parser = vim.treesitter.get_parser(buf, 'lua')
    local new_query = vim.treesitter.parse_query(
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

-- Display session data in given buffer.
-- Data may optionally contain "file" key with path to session file.
function M.display_session(data, buf)
    -- (a bit hacky) way to easily get syntax highlighting - just format everything
    -- as valid Lua code and set filetype.

    buf = buf or vim.api.nvim_get_current_buf()

    local lines = {}

    table.insert(lines, 'name = ' .. vim.inspect(data.name))
    table.insert(lines, 'file = ' .. vim.inspect(data.file))
    table.insert(lines, 'cwd = ' .. vim.inspect(data.cwd))
    table.insert(lines, '')

    local user_data = vim.inspect(data.user_data, { indent = '    ' })
    user_data = split_lines(user_data)
    table.insert(lines, 'user_data = ' .. user_data[1])
    for i = 2, #user_data do
        table.insert(lines, user_data[i])
    end

    table.insert(lines, '')
    table.insert(lines, 'vimscript = [[')
    local vimscript = split_lines(data.vimscript, true)
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
