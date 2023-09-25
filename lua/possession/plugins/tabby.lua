local M = {}

local utils = require('possession.utils')

local has_plugin = utils.bind(utils.has_module, 'tabby')

function M.before_save(opts, name)
    if not has_plugin() then
        return {}
    end

    local tab_names = {}

    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local fallback_nil = function()
            return nil
        end
        -- Get a name that was explicitly set (in tab variable), else we want nil
        local name = require('tabby.feature.tab_name').get(tab, { name_fallback = fallback_nil })
        if name then
            -- We must use string keys or else json.encode may assume it's a list
            local num = tostring(vim.api.nvim_tabpage_get_number(tab))
            tab_names[num] = name
        end
    end

    return {
        tab_names = tab_names,
    }
end

function M.after_load(opts, name, plugin_data)
    local tab_names = plugin_data.tab_names or {}
    if #tab_names == 0 or not has_plugin() then
        return
    end

    local num2id = utils.tab_num_to_id_map()
    for num, tab_name in pairs(tab_names) do
        local tab = num2id[tonumber(num)]
        if tab and vim.api.nvim_tabpage_is_valid(tab) then
            require('tabby.feature.tab_name').set(tab, tab_name)
        end
    end
end

return M
