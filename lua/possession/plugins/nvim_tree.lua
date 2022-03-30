local M = {}

local utils = require('possession.utils')

local has_nvim_tree = pcall(require, 'nvim-tree')

-- Close nvim-tree windows in given tab (id), return true if closed.
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

-- Open nvim-tree in given tab numbers.
local function open_tree(tab_nums)
    local nvim_tree = require('nvim-tree')
    local num2id = utils.tab_num_to_id_map()
    local initial = vim.api.nvim_get_current_tabpage()

    for _, tab_num in ipairs(tab_nums) do
        local tab = num2id[tab_num]
        if tab then
            vim.api.nvim_set_current_tabpage(tab)
            local win = vim.api.nvim_get_current_win()

            nvim_tree.open()

            -- Try to restore window
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_current_win(win)
            end
        end
    end

    vim.api.nvim_set_current_tabpage(initial)
end

function M.before_save(opts, name)
    if not has_nvim_tree then
        return {}
    end

    -- First close nvim-tree in tabs, then get numbers, filtering out any tabs that were closed.
    -- TODO: restore tabs that have been closed? probably not worth to handle this edge case
    local tabs = vim.tbl_filter(close_tree, vim.api.nvim_list_tabpages())
    local nums = utils.filter_map(function(tab)
        local valid = vim.api.nvim_tabpage_is_valid(tab)
        return valid and vim.api.nvim_tabpage_get_number(tab) or nil
    end, tabs)

    return {
        tabs = nums,
    }
end

function M.after_save(opts, name, plugin_data, aborted)
    if plugin_data and plugin_data.tabs then
        open_tree(plugin_data.tabs)
    end
end

function M.after_load(opts, name, plugin_data)
    if not has_nvim_tree then
        return
    end

    if plugin_data and plugin_data.tabs then
        open_tree(plugin_data.tabs)
    end
end

return M
