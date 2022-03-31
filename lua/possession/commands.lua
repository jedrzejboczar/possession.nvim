local M = {}

local session = require('possession.session')
local utils = require('possession.utils')
local display = require('possession.display')
local paths = require('possession.paths')
local migrate = require('possession.migrate')

local function complete_list(candidates, opts)
    opts = vim.tbl_extend('force', {
        sort = true,
    }, opts or {})

    vim.validate { candidates = { candidates, { 'table', 'function' } } }

    local get_candidates = function()
        local list = type(candidates) == 'function' and candidates() or candidates
        if opts.sort then
            table.sort(list)
        end
        return list
    end

    return function(arg_lead, cmd_line, cursor_pos)
        return vim.tbl_filter(function(c)
            return vim.startswith(c, arg_lead)
        end, get_candidates())
    end
end

-- Limits filesystem access by caching the results by time
M.complete_session = complete_list(utils.throttle(function()
    local files = vim.tbl_keys(session.list { no_read = true })
    return vim.tbl_map(paths.session_name, files)
end, 3000))

local function get_name(name)
    if not name or name == '' then
        local path = session.last()
        if not path then
            utils.error('Cannot find last loaded session name')
            return nil
        end
        name = paths.session_name(path)
    end
    return name
end

function M.save(name, no_confirm)
    local name = get_name(name)
    if name then
        session.save(name, { no_confirm = no_confirm })
    end
end

function M.load(name)
    local name = get_name(name)
    if name then
        session.load(name)
    end
end

function M.delete(name)
    local name = get_name(name)
    if name then
        session.delete(name)
    end
end

function M.show(name)
    local name = get_name(name)
    if not name then
        return
    end

    local path = paths.session(name)
    local data = vim.json.decode(path:read())
    data.file = path:absolute()

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    display.in_buffer(data, buf)
    vim.api.nvim_win_set_buf(0, buf)
end

function M.list(full)
    local sessions = session.list()
    local lines = {}
    for file, data in pairs(sessions) do
        table.insert(lines, 'Name: ' .. data.name)
        table.insert(lines, '  File: ' .. file)
        table.insert(lines, '  Cwd: ' .. data.cwd)

        table.insert(lines, '  User data:')
        local user_data = vim.inspect(data.user_data, { indent = '    ' })
        for _, line in ipairs(vim.split(user_data, '\n', { plain = true })) do
            table.insert(lines, '  ' .. line)
        end

        if full then
            -- Does not really make sense to list vimscript, at least join lines.
            table.insert(lines, '  Vimscript: ' .. data.vimscript:gsub('\n', '\\n'))
        end
    end
    print(table.concat(lines, '\n'))
end

function M.migrate(path)
    if vim.fn.getftype(path) == 'file' then
        migrate.migrate(path)
    else
        migrate.migrate_dir(path)
    end
end

return M
