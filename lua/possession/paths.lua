local M = {}

local Path = require('plenary.path')
local config = require('possession.config')
local utils = require('possession.utils')

--- Get session path
---@param name string
function M.session(name)
    -- Not technically need but should guard against potential errors
    assert(not vim.endswith(name, '.json'), 'Name should not end with .json')
    return Path:new(config.session_dir) / (name .. '.json')
end

--- Get path to symlink that points to last session
function M.last_session_link()
    return Path:new(config.session_dir) / '__last__'
end

--- Get short session path for printing
---@param name string
function M.session_short(name)
    local path = M.session(name)
    return utils.relative_path(path, config.session_dir)
end

--- Get session name from a session file name
--- In general session file name should be in the form "<name>.json",
--- where <name> is the same as the value of JSON key "name", but if for some reason
--- those don't match (someone changed file name), better fall back to JSON contents.
---@param name string
function M.session_name(path)
    return vim.fn.fnamemodify(Path:new(path):absolute(), ':t:r')
end

return M
