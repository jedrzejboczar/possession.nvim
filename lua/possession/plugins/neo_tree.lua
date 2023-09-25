local M = {}

local utils = require('possession.utils')

local has_plugin = utils.bind(utils.has_module, 'neo-tree')

local find_tab_buf = function(tab)
    return utils.find_tab_buf(tab, function(buf)
        return vim.api.nvim_buf_get_option(buf, 'filetype') == 'neo-tree'
    end)
end

local function close_tree(tab)
    local buf = find_tab_buf(tab)
    if buf then
        vim.api.nvim_buf_delete(buf, { force = true })
        return true
    end
    return false
end

local function open_tree(tab_nums)
    local tabs = utils.tab_nums_to_ids(tab_nums)
    utils.for_each_tab(tabs, function(tab)
        vim.cmd('Neotree show')
        -- Need to wait as neo-tree does some async stuff
        vim.wait(100, function()
            return find_tab_buf(tab) ~= nil
        end)
    end)
end

function M.before_save(opts, name)
    if not has_plugin() then
        return {}
    end

    -- First close in tabs, then get numbers, filtering out any tabs that were closed.
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
    if not has_plugin() then
        return
    end

    if plugin_data and plugin_data.tabs then
        open_tree(plugin_data.tabs)
    end
end

function M.after_load(opts, name, plugin_data)
    if plugin_data and plugin_data.tabs and has_plugin() then
        open_tree(plugin_data.tabs)
    end
end

return M
