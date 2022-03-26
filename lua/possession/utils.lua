local M = {}

local Path = require('plenary.path')
local config = require('possession.config')

function M.info(...)
    if not config.silent then
        vim.notify(string.format(...))
    end
end

-- Get session path
function M.session_path(name)
    -- Not technically need but should guard against potential errors
    assert(not vim.endswith(name, '.json'), 'Name should not end with .json')
    return Path:new(config.session_dir) / (name .. '.json')
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

return M
