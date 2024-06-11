local M = {}

local config = require('possession.config')

function M.debug(...)
    local logging = require('possession.logging')
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
    local logging = require('possession.logging')
    local log_fn = config.silent and logging.to_file or logging.to_all
    log_fn(string.format(...), vim.log.levels.INFO)
end

function M.warn(...)
    local logging = require('possession.logging')
    logging.to_all(string.format(...), vim.log.levels.WARN)
end

function M.error(...)
    local logging = require('possession.logging')
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

--- Convert tab numbers to ids (handles), lists may have different lengths if some tabs were not found!
---@param tab_nums integer[]
---@return integer[] tab_ids
function M.tab_nums_to_ids(tab_nums)
    local num2id = M.tab_num_to_id_map()
    local ids = {}
    for _, num in ipairs(tab_nums) do -- vim.tbl_map can leave nil "holes" inside the list
        table.insert(ids, num2id[num])
    end
    return ids
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

---@param filter? vim.lsp.get_clients.Filter
local function lsp_get_clients(filter)
    if vim.fn.has('nvim-0.10') ~= 0 then
        return vim.lsp.get_clients(filter)
    else
        return vim.lsp.get_active_clients(filter)
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
    vim.lsp.stop_client(lsp_get_clients())
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

--- Executed fn in each tab, then restore to initial tab
---@param tabs integer[] tab ids, not tab numbers
---@param fn fun(tab: integer)
function M.for_each_tab(tabs, fn)
    local initial = vim.api.nvim_get_current_tabpage()

    for _, tab in ipairs(tabs) do
        if vim.api.nvim_tabpage_is_valid(tab) then
            vim.api.nvim_set_current_tabpage(tab)
            local win = vim.api.nvim_get_current_win()

            fn(tab)

            -- Try to restore window
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_current_win(win)
            end
        end
    end

    vim.api.nvim_set_current_tabpage(initial)
end

--- Make relative path (only if 'path' is child of 'rel_to' or 'force' is set), replace '~' unless normalize=false
---@param path string|Path
---@param rel_to string|Path
---@param opts? { force?: boolean, normalize?: boolean } defaults to force=false, normalize=true
---@return string
function M.relative_path(path, rel_to, opts)
    local Path = require('plenary.path')

    opts = vim.tbl_extend('force', {
        force = false,
        normalize = true,
    }, opts or {})

    path = Path:new(path)
    rel_to = Path:new(rel_to)

    if opts.force or vim.startswith(path:absolute(), rel_to:absolute()) then
        local cwd = rel_to:absolute()
        if opts.normalize then
            return path:normalize(cwd)
        else
            return path:make_relative(cwd).filename
        end
    else
        if opts.normalize then
            return path:normalize()
        else
            return path.filename
        end
    end
end

---@param strings string[]
---@return string
function M.find_common_prefix(strings)
    if #strings == 0 then
        return ''
    end
    if #strings == 1 then
        return strings[1]
    end

    -- Simple algorithm: sort the list, then find longest prefix between two most different strings
    strings = vim.deepcopy(strings)
    table.sort(strings)

    local max_len = math.min(#strings[1], #strings[#strings])
    local len = 0
    for i = 1, max_len do
        if strings[1]:sub(i, i) ~= strings[#strings]:sub(i, i) then
            break
        end
        len = i
    end

    return strings[1]:sub(1, len)
end

--- Recursively count number of non-nil leaves in nested table
---@param t table
---@return integer
function M.tbl_deep_count(t)
    local n = 0
    for _, val in pairs(t) do
        if type(val) == 'table' then
            n = n + M.tbl_deep_count(val)
        elseif val ~= nil then
            n = n + 1
        end
    end
    return n
end

M.path_sep = (function()
    local is_windows = vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
    return is_windows and '\\' or '/'
end)()

---@generic F: function
---@param fn F
---@param catch? fun(err: string): boolean? return `true` to prevent re-rising the error
---@param finally? fun(ok: boolean, err: string) runs always after fn and catch
---@return F
---@nodiscard
function M.try(fn, catch, finally)
    return function(...)
        local ret = { xpcall(fn, debug.traceback, ...) }
        local ok, err = unpack(ret)

        if not ok and catch then
            local caught = catch(err)
            if caught then
                ok = true
            end
        end

        if finally then
            finally(ok, err)
        end

        if not ok then
            error(err, 2)
        else
            return unpack(ret, 2)
        end
    end
end

---@param keys string[]
local function lazy_index(mod, keys)
    return setmetatable({}, {
        __call = function(_, ...)
            local fn = vim.tbl_get(mod(), unpack(keys))
            return fn(...)
        end,
        __index = function(_, key)
            return lazy_index(mod, vim.list_extend(vim.list_slice(keys), { key }))
        end,
    })
end

---@param path string
function M.lazy_mod(path)
    local load = function()
        return require(path)
    end
    local mod
    mod = setmetatable({ path = path }, {
        __call = load,
        __index = function(_, key)
            return lazy_index(mod, { key })
        end,
    })
    return mod
end

---Encode filename removing any potentially problematic characters
---see: https://github.com/jedrzejboczar/possession.nvim/pull/55
---@param str string
function M.percent_encode(str)
    return string.gsub(str, '([^%w%-%_%.])', function(c)
        return string.format('%%%02X', string.byte(c))
    end)
end

---Decode filename previously encoded with percent_encode
---@param str string
function M.percent_decode(str)
    return string.gsub(str, '%%(%x%x)', function(h)
        return string.char(tonumber(h, 16))
    end)
end

--- Update access and modification time of a file to the current time
---@param path string
function M.touch(path)
    local sec, usec = vim.uv.gettimeofday()
    local t = sec + usec / 1000000
    vim.uv.fs_utime(path, t, t)
end

return M
