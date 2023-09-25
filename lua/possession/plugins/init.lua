local M = {}

local config = require('possession.config')
local utils = require('possession.utils')

local plugins = {
    'close_windows',
    'delete_hidden_buffers',
    'nvim_tree',
    'tabby',
    'dap',
    'delete_buffers',
}

local function req(plugin)
    return require('possession.plugins.' .. plugin)
end

local function get_config(plugin)
    local c = config.plugins[plugin]
    vim.validate { config = { c, utils.is_type { 'boolean', 'table' } } }
    if type(c) == 'boolean' then
        return c and {} or nil
    end
    return c
end

local function hook_active(plugin, hook)
    local c = get_config(plugin)
    if not c then
        return false
    end
    -- If `hooks` is missing then all hooks are enabled
    return c.hooks == nil or vim.tbl_contains(c.hooks, hook)
end

local function get_enabled(hook)
    return vim.tbl_filter(function(p)
        return hook_active(p, hook) and req(p)[hook]
    end, plugins)
end

-- Helper using the fact that currently all hooks have the same argument order
-- and so any excessive arguments will be ignored. This also ensures we always
-- pass a valid table for plugin_data.
local function call_plugin(hook, p, name, plugin_data, aborted)
    local c = get_config(p)
    local pd = plugin_data or {}
    utils.debug(
        '%s: %s(%s)',
        hook,
        p,
        vim.inspect {
            opts = c,
            name = name,
            plugin_data = pd,
            aborted = aborted,
        }
    )
    local data = req(p)[hook](c, name, pd, aborted)
    utils.debug('%s: %s => %s', hook, p, vim.inspect(data))
    return data
end

---@param name string
---@return table
function M.before_save(name)
    local plugin_data = {}
    for _, p in ipairs(get_enabled('before_save')) do
        local data = call_plugin('before_save', p, name)

        -- Plugin can abort saving
        if not data then
            return nil
        else
            -- Add to saved plugin data
            plugin_data[p] = data
        end
    end
    return plugin_data
end

---@param name string
---@param plugin_data table
---@param aborted boolean
function M.after_save(name, plugin_data, aborted)
    for _, p in ipairs(get_enabled('after_save')) do
        call_plugin('after_save', p, name, plugin_data[p], aborted)
    end
end

---@param name string
---@param plugin_data table
---@return table
function M.before_load(name, plugin_data)
    for _, p in ipairs(get_enabled('before_load')) do
        local data = call_plugin('before_load', p, name, plugin_data[p])
        if not data then
            return nil
        else
            plugin_data[p] = data
        end
    end
    return plugin_data
end

---@param name string
---@param plugin_data table
function M.after_load(name, plugin_data)
    for _, p in ipairs(get_enabled('after_load')) do
        call_plugin('after_load', p, name, plugin_data[p])
    end
end

--- Crate a basic implementation of plugin hooks that does not store any session data.
---@param fn fun(opts: table): boolean receives plugin config and should return `true` on success
function M.implement_basic_hooks(fn)
    return {
        before_save = function(opts, name)
            return fn(opts) and {}
        end,
        after_save = function(opts, name, plugin_data, aborted)
            if not aborted then
                fn(opts)
            end
        end,
        before_load = function(opts, name, plugin_data)
            return fn(opts) and plugin_data
        end,
        after_load = function(opts, name, plugin_data)
            fn(opts)
        end,
    }
end

return M
