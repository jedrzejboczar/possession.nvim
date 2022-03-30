local M = {}

local config = require('possession.config')

local plugins = {
    'nvim_tree',
}

local function req(plugin)
    return require('possession.plugins.' .. plugin)
end

local function get_config(plugin)
    local c = config.plugins[plugin]
    vim.validate { config = { c, { 'boolean', 'table' } } }
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

function M.before_save(name)
    local plugin_data = {}
    for _, p in ipairs(get_enabled('before_save')) do
        local data = req(p).before_save(get_config(p), name)
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

function M.after_save(name, plugin_data, aborted)
    for _, p in ipairs(get_enabled('after_save')) do
        req(p).after_save(get_config(p), name, plugin_data[p], aborted)
    end
end

function M.before_load(name, plugin_data)
    for _, p in ipairs(get_enabled('before_load')) do
        local data = req(p).before_load(get_config(p), name, plugin_data[p])
        if not data then
            return nil
        else
            plugin_data[p] = data
        end
    end
    return plugin_data
end

function M.after_load(name, plugin_data)
    for _, p in ipairs(get_enabled('after_load')) do
        req(p).after_load(get_config(p), name, plugin_data[p])
    end
end

return M
