local M = {}

local Path = require('plenary.path')
local session = require('possession.session')
local utils = require('possession.utils')

-- Group sessions by given key
--@key string|function: returns a key from session data used for grouping
-- sessions with key resulting in nil will be ignored
--@sessions table?: if not specified session.list() will be used
function M.group_by(key, sessions)
    vim.validate {
        key = { key, { 'string', 'function' } },
        sessions = { sessions, { 'table', 'nil' } },
    }

    sessions = sessions or session.list()

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
    for _, s in ipairs(sessions) do
        local k = key(s)
        if key then
            if not groups[k] then
                groups[k] = {}
            end
            table.insert(groups[k], s)
        end
    end

    return groups
end

-- Get a sessions as a list-like table
-- As opposed to `require('possession.session').list`, which returns a map-like table,
-- this will return a list-like table with additional `file` key embedded into session data.
--@param sessions table?: map-like table of sessions {filename: data}
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

function M.group_by_root_dir(root_dirs, sessions)
    if type(root_dirs) == 'string' then
        root_dirs = { root_dirs }
    end
    return M.group_by(function(s)
        for _, dir in ipairs(root_dirs) do
            dir = vim.fn.fnamemodify(vim.fn.expand(dir), ':p')
            print(dir, s.cwd)
            if vim.startswith(vim.fn.fnamemodify(s.cwd, ':p'), dir) then
                return dir
            end
        end
    end, sessions)
end

return M
