local M = {}

local config = require('possession.config')
local utils = require('possession.utils')

local plugins = {
    'close_windows',
    'delete_hidden_buffers',
    'nvim_tree',
    'neo_tree',
    'symbols_outline',
    'outline',
    'tabby',
    'neotest',
    'dapui',
    'dap',
    'delete_buffers',
    'stop_lsp_clients',
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

---@class possession.FileTreePluginOpts
---@field buf_is_plugin fun(buf: integer): boolean check if given buffer belongs to the plugin, e.g. by filetype
---@field open_in_tab fun(tab: integer) open the plugin in tab (tab is the current tab when this function is called)
---@field close_in_tab? fun(tab: integer): boolean if not provided then deletes all plugin buffers
---@field has_plugin? string|fun(): boolean if it is a string will try to require lua module, if nil then assume true

--- Generate implementation for plugins that just open "docks" per tab, like file-trees (nvim-tree, neo-tree, ...)
---@param name string
---@param opts possession.FileTreePluginOpts
function M.implement_file_tree_plugin_hooks(name, opts)
    local find_tab_buf = function(tab)
        return utils.find_tab_buf(tab, opts.buf_is_plugin)
    end

    local close_in_tab
    if opts.close_in_tab then
        -- use custom close implementation
        close_in_tab = function(tab)
            local buf = find_tab_buf(tab)
            if buf and opts.close_in_tab(tab) then
                return true
            end
            return false
        end
    else
        -- default implementation - delete all buffers
        close_in_tab = function(tab)
            local max_bufs = 100 -- avoid infinite loops when something is wrong
            local n = 0

            local buf = find_tab_buf(tab)
            while buf and n < 10 do
                if n >= max_bufs then
                    utils.warn('Could not close plugin %s in tab %d after %d attempts', name, tab, n)
                    return false
                end

                vim.api.nvim_buf_delete(buf, { force = true })
                buf = find_tab_buf(tab)
                n = n + 1
            end

            return n > 0
        end
    end

    local open_in_tab_nums = function(tab_nums)
        local tabs = utils.tab_nums_to_ids(tab_nums)
        utils.for_each_tab(tabs, opts.open_in_tab)
    end

    local has_plugin = function()
        if not opts.has_plugin then
            return true
        elseif type(opts.has_plugin) == 'function' then
            return opts.has_plugin
        else
            local mod = opts.has_plugin --[[@as string]]
            return utils.has_module(mod)
        end
    end

    return {
        before_save = function(_opts, _name)
            if not has_plugin() then
                return {}
            end

            -- First close in tabs, then get numbers, filtering out any tabs that were closed.
            -- TODO: restore tabs that have been closed? probably not worth to handle this edge case
            local tabs = vim.tbl_filter(close_in_tab, vim.api.nvim_list_tabpages())
            local nums = utils.filter_map(function(tab)
                local valid = vim.api.nvim_tabpage_is_valid(tab)
                return valid and vim.api.nvim_tabpage_get_number(tab) or nil
            end, tabs)

            return {
                tabs = nums,
            }
        end,
        after_save = function(_opts, _name, plugin_data, _aborted)
            if not has_plugin() then
                return
            end

            if plugin_data and plugin_data.tabs then
                open_in_tab_nums(plugin_data.tabs)
            end
        end,
        after_load = function(_opts, _name, plugin_data)
            if plugin_data and plugin_data.tabs and has_plugin() then
                open_in_tab_nums(plugin_data.tabs)
            end
        end,
    }
end

return M
