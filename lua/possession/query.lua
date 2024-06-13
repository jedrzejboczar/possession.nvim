local M = {}

local session = require('possession.session')
local utils = require('possession.utils')
local config = require('possession.config')

--- Get a sessions as a list-like table
---@param sessions? table<string, table> like from possession.session.list()
---@return table[] list of session data with additional `file` key
function M.as_list(sessions)
    sessions = sessions or session.list()
    local list = {}
    for file, data in pairs(sessions) do
        if data.file then
            utils.warn('Unexpected "file" key already in session data')
        else
            data.file = file
        end
        table.insert(list, data)
    end
    return list
end

--- Filters a list of sessions
---@param sessions table[] list of sessions from `as_list`
---@param opts { cwd: string }
function M.filter_by(sessions, opts)
    return vim.tbl_filter(function(s)
        return opts.cwd == s.cwd
    end, sessions)
end

---@alias possession.QuerySortKey 'name'|'atime'|'mtime'|'ctime'

--- Sort a list of sessions in-place
---@param sessions table[] list of sessions from `as_list`
---@param key possession.QuerySortKey key to sort by: name, stat(2) timestamps
---@param descending? boolean
function M.sort_by(sessions, key, descending)
    local get_key

    if key == 'name' then
        get_key = function(s)
            return s.name
        end
    elseif vim.tbl_contains({ 'atime', 'mtime', 'ctime' }, key) then
        local get_time = function(file)
            local stat = vim.loop.fs_stat(file)
            if not stat then
                return 0
            end
            local t = stat[key]
            -- use millis to fit in Lua's max float "integer precision" of 53 bits
            return math.floor(t.sec * 1000 + t.nsec / 1000000)
        end
        -- cache filesystem access
        local times = {}
        get_key = function(s)
            if not s.file then
                return 0
            elseif times[s.file] then
                return times[s.file]
            end
            local t = get_time(s.file)
            times[s.file] = t
            return t
        end
    end

    local cmp
    if descending then
        cmp = function(a, b)
            return a > b
        end
    else
        cmp = function(a, b)
            return a < b
        end
    end

    table.sort(sessions, function(a, b)
        return cmp(get_key(a), get_key(b))
    end)
end

--- Group sessions by given key
--- Returns two values, first is a table of groups {key: sessions}
--- and the second one is a list of non-matching sessions (ones for which key was nil).
---@param key string|fun(sdata: table): string a key from session data used for grouping sessions
---@param sessions? table[] if not specified as_list() will be used
---@return table<string, table[]>
---@return table[]
function M.group_by(key, sessions)
    vim.validate {
        key = { key, utils.is_type { 'string', 'function' } },
        sessions = { sessions, utils.is_type { 'table', 'nil' } },
    }

    sessions = sessions or M.as_list()

    local tmp = {}
    for file, data in pairs(sessions) do
        data.file = file
        table.insert(tmp, data)
    end
    sessions = tmp

    if type(key) ~= 'function' then
        key = function(s)
            return s[key]
        end
    end

    local groups = {}
    local others = {}
    for _, s in ipairs(sessions) do
        local k = key(s)
        -- Prevent potential errors
        assert(type(k) ~= 'function', 'Key function should not be a higher-order function')
        if k then
            if not groups[k] then
                groups[k] = {}
            end
            table.insert(groups[k], s)
        else
            table.insert(others, s)
        end
    end

    return groups, others
end

---@param dir string
---@param root string
---@return boolean
local function is_descendant(dir, root)
    dir = assert(vim.fn.fnamemodify(vim.fn.expand(dir), ':p'))
    root = assert(vim.fn.fnamemodify(vim.fn.expand(root), ':p'))
    return vim.startswith(dir, root)
end

-- Match sessions based on parent directory matching.
-- Session will be assigned to the group of the first directory from `root_dirs`
-- that is a parent of `session.cwd`.
---@param root_dirs string|string[] root directory(-ies) that define the groups
---@return fun(sdata: table): string?
function M.by_root_dir(root_dirs)
    if type(root_dirs) == 'string' then
        root_dirs = { root_dirs }
    end
    return function(s)
        for _, root in ipairs(root_dirs) do
            if is_descendant(s.cwd, root) then
                return root
            end
        end
    end
end

-- Match sessions by workspace, where each workspace has a list of root_dirs.
---@param workspaces table<string, string[]> {name: root_dirs}
---@return fun(sdata: table): string?
function M.by_workspace(workspaces)
    local matchers = utils.tbl_map_values(workspaces, M.by_root_dir)
    return function(s)
        for _, name in ipairs(vim.tbl_keys(workspaces)) do
            if matchers[name](s) then
                return name
            end
        end
    end
end

---@class possession.WorkspaceSpec
---@field [1] string name
---@field [2] string prefix
---@field [3] string root dirs

---@class possession.SessionWithShortcut
---@field [1] string shortcut
---@field [2] table session data

---@class possession.WorkspaceInfo
---@field [1] string name
---@field [2] possession.SessionWithShortcut[]

---@class possession.WorkspacesWithShortcutsOpts
---@field sessions? table[]
---@field others_prefix? string prefix for sessions without a workspace, defaults to 's'
---@field sort_by? string|fun(sdata: table): string key for sorting sessions within a workspace (default: session.name)
---@field map_session? fun(sdata: table): any convert all sessions in the retuned data to different values (normally
---       returns session_data tables) useful to just get session names in the output instead of tables

--- Do-all helper for generating session data suitable for usage in a startup screen.
---
--- This will group sessions by workspace, where each workspace is defined by
--- a list of root directories. Shortcuts in the form {prefix}{number} will be
--- generated for sessions in each workspace. The returned data can be used
--- to generate startup screen buttons.
---
---@param workspace_specs possession.WorkspaceSpec[]
---@param opts? possession.WorkspacesWithShortcutsOpts
---@return possession.WorkspaceInfo[] workspaces
---@return possession.SessionWithShortcut[] sessions that did not match any workspace
function M.workspaces_with_shortcuts(workspace_specs, opts)
    opts = vim.tbl_extend('force', {
        sessions = nil,
        others_prefix = 's',
        sort_by = 'name',
        map_session = nil,
    }, opts or {})

    vim.validate {
        workspace_specs = { workspace_specs, 'table' },
        sessions = { opts.sessions, utils.is_type { 'nil', 'table' } },
        others_prefix = { opts.others_prefix, 'string' },
        sort_by = { opts.sort_by, utils.is_type { 'nil', 'string' } },
        map_session = { opts.map_session, utils.is_type { 'nil', 'function' } },
    }

    local workspaces = {} -- {name: root_dir} for by_workspace
    local prefixes = {} -- {name: prefix} for generating shortcuts
    local workspace_order = {} -- {name} to return data in order
    for _, specs in ipairs(workspace_specs) do
        local name, prefix, root_dirs = unpack(specs)
        assert(
            prefix ~= opts.others_prefix,
            string.format('Duplicate prefix "%s", specify different opts.other_prefix', prefix)
        )
        workspaces[name] = root_dirs
        prefixes[name] = prefix
        table.insert(workspace_order, name)
    end

    local groups, others = M.group_by(M.by_workspace(workspaces), opts.sessions)

    ---@param prefix string
    ---@param sessions table[]
    ---@return possession.SessionWithShortcut[]
    local with_shortcuts = function(prefix, sessions)
        if opts.sort_by then
            local get = type(opts.sort_by) == 'function' and opts.sort_by
                or function(s)
                    return s[opts.sort_by]
                end
            table.sort(sessions, function(a, b)
                return get(a) < get(b)
            end)
        end

        local i = 0
        return vim.tbl_map(function(s)
            i = i + 1
            local shortcut = string.format('%s%d', prefix, i)
            if opts.map_session then
                s = opts.map_session(s)
            end
            return { shortcut, s }
        end, sessions)
    end

    groups = vim.tbl_map(function(name)
        return { name, with_shortcuts(prefixes[name], groups[name] or {}) }
    end, workspace_order)
    others = with_shortcuts(opts.others_prefix, others)

    return groups, others
end

---@class possession.AlphaWorkspaceLayoutOpts
---@field title_highlight? string highlight group for section titles
---@field others_name? string name used for section with sessions not matching any workspace

--- Example session layout generator for alpha.nvim.
--- This will group sessions by workspaces and return an alpha.nvim 'group' table.
---
---@param workspace_specs possession.WorkspaceSpec[]
---@param create_button fun(shortcut: string, text: string, keybind: string): table generates alpha.nvim button, see:
---https://github.com/goolord/alpha-nvim/blob/8a1477d8b99a931530f3cfb70f6805b759bebbf7/lua/alpha/themes/startify.lua#L28
---@param opts? possession.AlphaWorkspaceLayoutOpts
function M.alpha_workspace_layout(workspace_specs, create_button, opts)
    opts = vim.tbl_extend('force', {
        title_highlight = 'Type',
        others_name = 'Sessions',
    }, opts or {})

    vim.validate {
        create_button = { create_button, 'function' },
        title_highlight = { opts.title_highlight, 'string' },
        others_name = { opts.others_name, 'string' },
    }

    -- Get lists of session names with shortcuts assigned
    local workspaces, others = M.workspaces_with_shortcuts(workspace_specs, {
        map_session = function(s)
            return s.name
        end,
    })

    -- Transform a sessions+shortcuts into alpha.nvim buttons
    local to_buttons = function(sessions_with_shortcuts)
        return vim.tbl_map(function(sws)
            local shortcut, session_name = unpack(sws)
            local cmd = string.format('<cmd>%s %s<cr>', config.commands.load, session_name)
            return create_button(shortcut, session_name, cmd)
        end, sessions_with_shortcuts)
    end

    -- Generate a workspace section
    local section = function(name, sessions_with_shortcuts)
        return {
            type = 'group',
            val = {
                { type = 'padding', val = 1 },
                { type = 'text', val = name, opts = { hl = opts.title_highlight } },
                { type = 'padding', val = 1 },
                { type = 'group', val = to_buttons(sessions_with_shortcuts) },
            },
        }
    end

    -- Create sections layout group
    local layout = {}
    if #others > 0 then
        table.insert(layout, section(opts.others_name, others))
    end
    for _, w in ipairs(workspaces) do
        local name, sessions_with_shortcuts = unpack(w)
        if #sessions_with_shortcuts > 0 then
            table.insert(layout, section(name, sessions_with_shortcuts))
        end
    end
    return layout
end

return M
