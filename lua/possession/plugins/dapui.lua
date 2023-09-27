local plugins = require('possession.plugins')

local function buf_is_plugin(buf)
    return vim.startswith(vim.api.nvim_buf_get_option(buf, 'filetype'), 'dapui_')
end

-- NOTE: dapui only supports a single ui so there is at most 1 tab, still it's easier to use this helper function
return plugins.implement_file_tree_plugin_hooks('dapui', {
    has_plugin = 'dapui',
    buf_is_plugin = buf_is_plugin,
    -- need to use dapui.close() because simple deletion of buffers causes errors for dapui
    close_in_tab = function(_tab)
        require('dapui').close()
        return true
    end,
    open_in_tab = function(tab)
        require('dapui').open()
    end,
})
