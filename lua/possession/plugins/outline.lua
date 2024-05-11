local plugins = require('possession.plugins')
local utils = require('possession.utils')

local function buf_is_plugin(buf)
    return vim.api.nvim_buf_get_option(buf, 'filetype') == 'Outline'
end

local find_tab_buf = function(tab)
    return utils.find_tab_buf(tab, buf_is_plugin)
end

-- NOTE: currently symbols-outline does not really work on per-tab basis so this does not make sense but in
-- theory symbols-outline could easily work like other file-trees so stick with this implementation for now
return plugins.implement_file_tree_plugin_hooks('symbols-outline', {
    has_plugin = 'outline',
    buf_is_plugin = buf_is_plugin,
    open_in_tab = function(tab)
        vim.cmd('OutlineOpen')
        -- Need to wait for some async stuff
        vim.wait(100, function()
            return find_tab_buf(tab) ~= nil
        end)
    end,
})
