local M = {}

local fun = require('plenary.fun')
local plugins = require('possession.plugins')
local utils = require('possession.utils')

local function is_floating(win)
    local cfg = vim.api.nvim_win_get_config(win)
    return cfg.relative and cfg.relative ~= ''
end

local function match_buf_opt(buf, option, candidates)
    local value = vim.api.nvim_buf_get_option(buf, option)
    return vim.tbl_contains(candidates, value)
end

local function match_window(match, win)
    local buf = vim.api.nvim_win_get_buf(win)
    return (
            (match.floating and is_floating(win))
            or match_buf_opt(buf, 'buftype', match.buftype)
            or match_buf_opt(buf, 'filetype', match.filetype)
            or utils.as_function(match.custom)(win)
        )
end

-- Close all windows that match predicates.
-- `opts` should have the same format as `config.plugins.close_windows`.
function M.close_windows(opts)
    local windows = vim.api.nvim_list_wins()
    local to_close = vim.tbl_filter(utils.bind(match_window, opts.match), windows)

    local preserve_layout = utils.as_function(opts.preserve_layout)
    local scratch = utils.lazy(function()
        return vim.api.nvim_create_buf(false, true)
    end)

    for _, win in ipairs(to_close) do
        -- Always close floating windows, others when not preserving layout
        if is_floating(win) or not preserve_layout(win) then
            vim.api.nvim_win_close(win, false)
        else
            vim.api.nvim_win_set_buf(win, scratch())
        end
    end

    return true
end

M = vim.tbl_extend('error', M, plugins.implement_basic_hooks(M.close_windows))

return M
