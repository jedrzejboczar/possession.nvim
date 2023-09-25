local plugins = require('possession.plugins')
local utils = require('possession.utils')

local function buf_is_plugin(buf)
    return vim.api.nvim_buf_get_option(buf, 'filetype') == 'neo-tree'
end

local find_tab_buf = function(tab)
    return utils.find_tab_buf(tab, buf_is_plugin)
end

-- TODO: we could use b:neo_tree_position/b:neo_tree_source to restore more details
return plugins.implement_file_tree_plugin_hooks('neo-tree', {
    has_plugin = 'neo-tree',
    buf_is_plugin = buf_is_plugin,
    open_in_tab = function(tab)
        vim.cmd('Neotree show')
        -- Need to wait as neo-tree does some async stuff
        vim.wait(100, function()
            return find_tab_buf(tab) ~= nil
        end)
    end,
})
