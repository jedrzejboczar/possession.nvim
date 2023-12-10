local plugins = require('possession.plugins')

-- NOTE: similarly to dapui, neotest only supports up to a single summary open, so we can use the helper function
return plugins.implement_file_tree_plugin_hooks('neotest', {
    has_plugin = 'neotest',
    buf_is_plugin = function(buf)
        return vim.api.nvim_buf_get_option(buf, 'filetype') == 'neotest-summary'
    end,
    -- also similarly to dapui, it's necessary to call close(), because simply deleting the buffer causes an error
    close_in_tab = function(_)
        require('neotest').summary.close()
        return true
    end,
    open_in_tab = function(_)
        require('neotest').summary.open()
    end,
})
