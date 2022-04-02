local M = {}

local utils = require('possession.utils')

local has_tabby = pcall(require, 'tabby')

function M.before_save(opts, name)
    if not has_tabby then
        return {}
    end

    local tab_names = {}

    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local fallback_nil = function()
            return nil
        end
        -- We must use string keys or else json.encode may assume it's a list
        local num = tostring(vim.api.nvim_tabpage_get_number(tab))
        tab_names[num] = require('tabby.util').get_tab_name(tab, fallback_nil)
    end

    return {
        tab_names = tab_names,
    }
end

function M.after_load(opts, name, plugin_data)
    if not has_tabby then
        return
    end

    local num2id = utils.tab_num_to_id_map()
    for num, tab_name in pairs(plugin_data.tab_names or {}) do
        local tab = num2id[tonumber(num)]
        if tab and vim.api.nvim_tabpage_is_valid(tab) then
            require('tabby.util').set_tab_name(tab, tab_name)
        end
    end
end

return M
