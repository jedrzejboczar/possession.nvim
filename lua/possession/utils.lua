local M = {}

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
        return function(...)
            return fn_or_value
        end
    end
end

function M.bind(fn, ...)
    local args = {...}
    return function(...)
        return fn(unpack(args), ...)
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

-- Map elements from `list` and filter out nil values.
function M.filter_map(fn, list)
    local filter = function(elem)
        return elem ~= nil
    end
    return vim.tbl_filter(filter, vim.tbl_map(fn, list))
end

-- Get a mapping from tabpage number to tabpage id (handle)
function M.tab_num_to_id_map()
    local mapping = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        mapping[vim.api.nvim_tabpage_get_number(tab)] = tab
    end
    return mapping
end

return M
