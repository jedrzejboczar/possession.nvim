local M = {}

local Path = require('plenary.path')
local config = require('possession.config')
local utils = require('possession.utils')

--- Get session path
---@param name string
function M.session(name)
    -- Not technically need but should guard against potential errors
    assert(not vim.endswith(name, '.json'), 'Name should not end with .json')
    return Path:new(config.session_dir) / (utils.percent_encode(name) .. '.json')
end

--- Get short session path for printing
---@param name string
function M.session_short(name)
    local path = M.session(name)
    return utils.relative_path(path, config.session_dir)
end

---@deprecated
function M.session_name(path)
    vim.deprecate('paths.session_name()', 'session.list() and get name from data', '?', 'possession')
    return vim.json.decode(Path:new(path):read()).name
end

--- Get global cwd for use as session name
---@return string
function M.cwd_session_name()
    local global_cwd = vim.fn.getcwd(-1, -1)
    return vim.fn.fnamemodify(global_cwd, ':~')
end

--- Vim expands the given dir, then converts it to an absolute path
function M.absolute_dir(dir)
    return Path:new(vim.fn.expand(dir)):absolute()
end

return M
