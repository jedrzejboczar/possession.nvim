local M = {}

local session = require('possession.session')
local display = require('possession.display')
local paths = require('possession.paths')
local migrate = require('possession.migrate')
local utils = require('possession.utils')

local function complete_list(candidates, opts)
    opts = vim.tbl_extend('force', {
        sort = true,
    }, opts or {})

    vim.validate { candidates = { candidates, utils.is_type { 'table', 'function' } } }

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

local function get_current()
    if not session.session_name then
        utils.error('No session is currently open')
        return nil
    end
    return session.session_name
end

local function get_last()
    local path = session.last()
    if not path then
        utils.error('Cannot find last loaded session name')
        return nil
    end
    return paths.session_name(path)
end

local function name_or(name, getter)
    return (name and name ~= '') and name or getter()
end

function M.save(name, no_confirm)
    name = name_or(name, get_current)
    if name then
        session.save(name, { no_confirm = no_confirm })
    end
end

function M.load(name)
    name = name_or(name, get_last)
    if name then
        session.load(name)
    end
end

function M.close(force)
    session.close(force)
end

function M.delete(name)
    name = name_or(name, get_current)
    if name then
        session.delete(name)
    end
end

function M.show(name)
    name = name_or(name, get_current)
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
    display.echo_sessions { vimscript = full }
end

function M.migrate(path)
    if vim.fn.getftype(path) == 'file' then
        migrate.migrate(path)
    else
        migrate.migrate_dir(path)
    end
end

return M
