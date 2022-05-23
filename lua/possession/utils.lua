local M = {}

local config = require('possession.config')

function M.debug(...)
    if config.debug then
        local args = { ... }
        -- TODO: test version with a function
        if type(args[1]) == 'function' then
            args = args[1](select(2, ...))
        end
        vim.notify(string.format(unpack(args)), vim.log.levels.DEBUG)
    end
end

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
    local args = { ... }
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

-- Return new table by applying fn as: {key: value} -> {key: fn(value, key)}
function M.tbl_map_values(tbl, fn)
    local new = {}
    for key, val in pairs(tbl) do
        new[key] = fn(val, key)
    end
    return new
end

function M.split_lines(s, trimempty)
    return vim.split(s, '\n', { plain = true, trimempty = trimempty })
end

-- Get a mapping from tabpage number to tabpage id (handle)
function M.tab_num_to_id_map()
    local mapping = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        mapping[vim.api.nvim_tabpage_get_number(tab)] = tab
    end
    return mapping
end

-- Return function that checks if values have given type/types.
-- Used to support older versions of vim.validate that only accept single type or a validator function.
-- TODO: create a vim.validate wrapper instead of having to remember about 0.6 compatibility
function M.is_type(types)
    if type(types) == 'string' then
        types = { types }
    end
    return function(value)
        return vim.tbl_contains(types, type(value))
    end
end

-- Clear the prompt (whatever printed on the command line)
function M.clear_prompt()
    vim.api.nvim_command('normal! :')
end

-- Ask the user a y/n question
--@param callback function(boolean): receives true on "yes" and false on "no"
function M.prompt_yes_no(prompt, callback)
    prompt = string.format('%s [y/N] ', prompt)
    if config.prompt_no_cr then -- use getchar so no <cr> is required
        print(prompt)
        local ans = vim.fn.nr2char(vim.fn.getchar())
        local is_confirmed = ans:lower():match('^y')
        M.clear_prompt()
        callback(is_confirmed)
    else -- use vim.ui.input
        vim.ui.input({ prompt = prompt }, function(answer)
            callback(vim.tbl_contains({ 'y', 'yes' }, answer and answer:lower()))
        end)
    end
end

return M
