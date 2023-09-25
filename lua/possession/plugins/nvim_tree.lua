local plugins = require('possession.plugins')

return plugins.implement_file_tree_plugin_hooks('nvim-tree', {
    has_plugin = 'nvim-tree',
    buf_is_plugin = function(buf)
        return vim.api.nvim_buf_get_option(buf, 'filetype') == 'NvimTree'
    end,
    open_in_tab = function(_tab)
        require('nvim-tree.api').tree.open()
    end,
})
