local M = {}

local Path = require('plenary.path')
local config = require('possession.config')

function M.info(...)
    if not config.silent then
        vim.notify(string.format(...))
    end
end

function M.warn(...)
    vim.notify(string.format(...), vim.log.levels.WARN)
end

function M.error(...)
    vim.notify(string.format(...), vim.log.levels.ERROR)
end

-- Get session path
function M.session_path(name)
    -- Not technically need but should guard against potential errors
    assert(not vim.endswith(name, '.json'), 'Name should not end with .json')
    return Path:new(config.session_dir) / (name .. '.json')
end

-- Get path to symlink that points to last session
function M.last_session_link_path()
    return Path:new(config.session_dir) / '__last__'
end

-- Get short session path for printing
function M.session_path_short(name)
    local path = M.session_path(name)
    if vim.startswith(path:absolute(), Path:new(config.session_dir):absolute()) then
        return path:make_relative(config.session_dir)
    else
        return path:absolute()
    end
end

-- Get session name from a session file name
-- In general session file name should be in the form "<name>.json",
-- where <name> is the same as the value of JSON key "name", but if for some reason
-- those don't match (someone changed file name), better fall back to JSON contents.
function M.session_name_from_path(path)
    return vim.fn.fnamemodify(Path:new(path):absolute(), ':t:r')
end

-- Change the path to last file (make the symlink point to `path`)
function M.update_last_session(path)
    -- Must unlink if exists because fs_symlink won't overwrite existing links
    local link_path = M.last_session_link_path()
    if link_path:exists() then
        link_path:rm()
    end
    vim.loop.fs_symlink(path:absolute(), link_path:absolute())
end

-- Run :mksession! and return output as string by writing to a temporary file
function M.mksession()
    local tmp = vim.fn.tempname()
    vim.cmd('mksession! ' .. tmp)
    return Path:new(tmp):read()
end

-- Wrap function with time based throttling - will cache results until
-- `timeout` milliseconds since last function call. Note that timestamp
-- does not change until we reach next libuv event loop step.
function M.throttle(fn, timeout)
    local last_time
    local cached
    return function(...)
        -- Recompute
        if not last_time or vim.loop.now() > last_time + timeout then
            cached = fn(...)
            last_time = vim.loop.now()
        end
        return cached
    end
end

-- Lazily evaluate a function, caching the result of the first call
-- for all subsequent calls ever.
function M.lazy(fn)
    local cached
    return function(...)
        if cached == nil then
            cached = fn(...)
            assert(cached ~= nil, 'lazy: fn returned nil')
        end
        return cached
    end
end

-- For variables that can be values or functions.
function M.as_function(fn_or_value)
    if type(fn_or_value) == 'function' then
        return fn_or_value
    else
        return function()
            return fn_or_value
        end
    end
end

-- Create a function that indexes given table
function M.getter(tbl)
    return function(key)
        return tbl[key]
    end
end

-- Transform list-like table to a set {val = true, ...}
function M.list_to_set(list)
    local set = {}
    for _, val in ipairs(list) do
        set[val] = true
    end
    return set
end

return M
