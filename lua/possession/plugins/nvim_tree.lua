local M = {}

local has_nvim_tree = pcall(require, 'nvim-tree')

local function close_tree(tab)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_get_option(buf, 'filetype') == 'NvimTree' then
            vim.api.nvim_buf_delete(buf, { force = true })
            return true
        end
    end
    return false
end

local function restore_tabs(tabs)
    local nvim_tree = require('nvim-tree')
    local initial_tab = vim.api.nvim_get_current_tabpage()

    for _, tab in ipairs(tabs) do
        vim.api.nvim_set_current_tabpage(tab)
        local win = vim.api.nvim_get_current_win()
        nvim_tree.open()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
        end
    end

    vim.api.nvim_set_current_tabpage(initial_tab)
end

function M.before_save(opts, name)
    if not has_nvim_tree then
        return {}
    end
    return {
        -- FIXME: we have to store tab numbers (indices) not IDs because
        -- when restoring tab IDs will be different
        tabs = vim.tbl_filter(close_tree, vim.api.nvim_list_tabpages()),
    }
end

function M.after_save(opts, name, plugin_data, aborted)
    if plugin_data and plugin_data.tabs then
        restore_tabs(plugin_data.tabs)
    end
end

function M.after_load(opts, name, plugin_data)
    if not has_nvim_tree then
        return
    end

    if plugin_data and plugin_data.tabs then
        restore_tabs(plugin_data.tabs)
    end
end

return M
