local M = {}

local config = require('possession.config')
local logging = require('possession.logging')

function M.debug(...)
    if config.debug then
        local log_fn = config.silent and logging.to_file or logging.to_all
        local args = { ... }
        -- TODO: test version with a function
        if type(args[1]) == 'function' then
            args = args[1](select(2, ...))
        end
        log_fn(string.format(unpack(args)), vim.log.levels.DEBUG)
    end
end

function M.info(...)
    local log_fn = config.silent and logging.to_file or logging.to_all
    log_fn(string.format(...), vim.log.levels.INFO)
end

function M.warn(...)
    logging.to_all(string.format(...), vim.log.levels.WARN)
end

function M.error(...)
    logging.to_all(string.format(...), vim.log.levels.ERROR)
end

--- Wrap function with time based throttling - will cache results until
--- `timeout` milliseconds since last function call. Note that timestamp
--- does not change until we reach next libuv event loop step.
---@generic T
---@param fn fun(...): T
---@param timeout integer
---@return fun(...): T
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

--- Lazily evaluate a function, caching the result of the first call
--- for all subsequent calls ever.
---@generic T
---@param fn fun(...): T
---@return fun(...): T
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
---@generic T
---@param fn_or_value T|fun(...): T
---@return fun(...): T
function M.as_function(fn_or_value)
    if type(fn_or_value) == 'function' then
        return fn_or_value
    else
        return function()
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

--- Create a function that indexes given table
---@generic K
---@generic V
---@param tbl table<K, V>
---@return fun(key: K): V
function M.getter(tbl)
    return function(key)
        return tbl[key]
    end
end

--- Transform list-like table to a set {val = true, ...}
---@generic T
---@param list T[]
---@return table<T, boolean>
function M.list_to_set(list)
    local set = {}
    for _, val in ipairs(list) do
        set[val] = true
    end
    return set
end

--- Map elements from `list` and filter out nil values.
---@generic T
---@generic U
---@param fn fun(v: T): U
---@param list T[]
---@return U[]
function M.filter_map(fn, list)
    local filter = function(elem)
        return elem ~= nil
    end
    return vim.tbl_filter(filter, vim.tbl_map(fn, list))
end

--- Return new table by applying fn as: {key: value} -> {key: fn(value, key)}
---@generic K
---@generic U
---@generic V
---@param tbl table<K, V>
---@param fn fun(v: V, k: K): U
---@return table<K, U>
function M.tbl_map_values(tbl, fn)
    local new = {}
    for key, val in pairs(tbl) do
        new[key] = fn(val, key)
    end
    return new
end

---@param s string
---@param trimempty? boolean
---@return string[]
function M.split_lines(s, trimempty)
    return vim.split(s, '\n', { plain = true, trimempty = trimempty })
end

--- Get a mapping from tabpage number to tabpage id (handle)
---@return table<integer, integer>
function M.tab_num_to_id_map()
    local mapping = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        mapping[vim.api.nvim_tabpage_get_number(tab)] = tab
    end
    return mapping
end

--- Return function that checks if values have given type/types.
--- Used to support older versions of vim.validate that only accept single type or a validator function.
---@param types string|string[]
---@return fun(v: any): boolean
function M.is_type(types)
    -- TODO: create a vim.validate wrapper instead of having to remember about 0.6 compatibility
    if type(types) == 'string' then
        types = { types }
    end
    return function(value)
        return vim.tbl_contains(types, type(value))
    end
end

--- Clear the prompt (whatever printed on the command line)
function M.clear_prompt()
    vim.api.nvim_command('normal! :')
end

--- Ask the user a y/n question
---@param prompt string
---@param callback fun(yes: boolean) receives true on "yes" and false on "no"
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

--- Delete all open buffers, avoiding potential errors
---@param force? boolean delete buffers with unsaved changes
function M.delete_all_buffers(force)
    -- Deleting the current buffer before deleting other buffers will cause autocmd "BufEnter" to be triggered.
    -- Lspconfig will use the invalid buffer handler in vim.schedule.
    -- So make sure the current buffer is the last loaded one to delete.
    local current_buffer = vim.api.nvim_get_current_buf()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer) and current_buffer ~= buffer then
            vim.api.nvim_buf_delete(buffer, { force = force })
        end
    end
    vim.api.nvim_buf_delete(current_buffer, { force = force })
    vim.lsp.stop_client(vim.lsp.get_active_clients())
end

---@param mod string
---@return boolean
function M.has_module(mod)
    return not not vim.F.npcall(require, mod)
end

---@param tab integer
---@param cond fun(buf: integer): boolean
---@return integer? buf
function M.find_tab_buf(tab, cond)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if cond(buf) then
            return buf
        end
    end
end

return M
