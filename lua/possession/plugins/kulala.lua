local plugins = require('possession.plugins')

return plugins.implement_file_tree_plugin_hooks('kulala', {
    buf_is_plugin = function(buf)
        return vim.api.nvim_buf_get_name(buf) == 'kulala://ui'
    end,
})
