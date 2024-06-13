local M = {}

local utils = require('possession.utils')

---@module "possession.session"
local session = utils.lazy_mod('possession.session')
---@module "possession.display"
local display = utils.lazy_mod('possession.display')
---@module "possession.paths"
local paths = utils.lazy_mod('possession.paths')
---@module "possession.migrate"
local migrate = utils.lazy_mod('possession.migrate')
---@module "possession.query"
local query = utils.lazy_mod('possession.query')

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

-- Limits filesystem access by caching the session names per command line access
---@type table<string, string>?
local cached_names
vim.api.nvim_create_autocmd('CmdlineLeave', {
    group = vim.api.nvim_create_augroup('possession.commands.complete', { clear = true }),
    callback = function()
        cached_names = nil
    end,
})

local function get_session_names()
    if not cached_names then
        cached_names = {}
        for file, data in pairs(session.list()) do
            cached_names[file] = data.name
        end
    end
    return cached_names
end

M.complete_session = complete_list(get_session_names)

local function get_current()
    local name = session.get_session_name()
    if not name then
        utils.error('No session is currently open - specify session name as an argument')
        return nil
    end
    return name
end

local function cwd_sessions()
    return query.filter_by(query.as_list(), { cwd = vim.fn.getcwd() })
end

---@param sessions? table[] list of sessions from `as_list`
local function get_last(sessions)
    sessions = sessions or query.as_list()
    query.sort_by(sessions, 'mtime', true)
    local last_session = sessions and sessions[1]
    return last_session and last_session.name
end

local function name_or(name, getter)
    return (name and name ~= '') and name or getter()
end

---@param name? string
---@param no_confirm? boolean
function M.save(name, no_confirm)
    name = name_or(name, session.get_session_name)
    local save = function(session_name)
        session.save(session_name, { no_confirm = no_confirm })
    end
    if name then
        save(name)
    else
        vim.ui.input({ prompt = 'Session name: ' }, save)
    end
end

---@param name? string
function M.load(name)
    name = name_or(name, get_last)
    if name then
        session.load(name)
    else
        utils.error('Cannot find last loaded session - specify session name as an argument')
    end
end

---@param no_confirm? boolean
function M.save_cwd(no_confirm)
    session.save(paths.cwd_session_name(), { no_confirm = no_confirm })
end

function M.load_cwd()
    session.load(paths.cwd_session_name())
end

function M.load_last(only_cwd)
    local last = get_last(cwd_sessions())
    if last then
        session.load(last, { skip_autosave = true })
        return last
    end
    utils.info('No session found to autoload')
end

local function maybe_input(value, opts, callback)
    if value then
        callback(value)
    else
        vim.ui.input(opts, callback)
    end
end

---@param name? string
---@param new_name? string
function M.rename(name, new_name)
    name = name_or(name, get_current)
    if not name then
        return
    end
    -- Fail with an error before asynchronous vim.ui.input kicks in
    if not session.exists(name) then
        utils.error('Session "%s" does not exist', name)
        return
    end
    maybe_input(new_name, { prompt = 'New session name: ', default = name }, function(resolved)
        if resolved then
            session.rename(name, resolved)
        end
    end)
end

---@param force? boolean
function M.close(force)
    session.close(force)
end

---@param name? string
function M.delete(name)
    name = name_or(name, get_current)
    if name then
        session.delete(name)
    end
end

---@param name? string
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

---@param cwd_only? string
---@param full? boolean
function M.list(cwd_only, full)
    local sessions = cwd_only and cwd_sessions() or query.as_list()
    display.echo_sessions { vimscript = full, sessions = sessions }
end

---@param path string
function M.migrate(path)
    if vim.fn.getftype(path) == 'file' then
        migrate.migrate(path)
    else
        migrate.migrate_dir(path)
    end
end

return M
