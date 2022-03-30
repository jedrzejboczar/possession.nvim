local M = {}

local plugins = require('possession.plugins')
local utils = require('possession.utils')

-- Delete all hidden buffers. Returns `false` on failure.
-- `opts` should have the same format as `config.plugins.delete_hidden_buffers`.
function M.delete_hidden_buffers(opts)
    local visible = utils.list_to_set(vim.tbl_map(vim.api.nvim_win_get_buf, vim.api.nvim_list_wins()))
    local hidden = vim.tbl_filter(utils.getter(visible), vim.api.nvim_list_bufs())

    for _, buf in ipairs(hidden) do
        if not pcall(vim.api.nvim_buf_delete, buf, { force = opts.force }) then
            utils.error('Cannot delete buffer with unsaved changes: "%s"', vim.api.nvim_buf_get_name(buf))
            return false
        end
    end

    return true
end

M = vim.tbl_extend('error', M, plugins.implement_basic_hooks(M.delete_hidden_buffers))

return M
