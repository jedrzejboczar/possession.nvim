local M = {}

local fun = require('plenary.fun')
local config = require('possession.config')
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
-- `opts` should have the same format as `config.close_windows`.
function M.close_windows(opts)
    local windows = vim.api.nvim_list_wins()
    local to_close = vim.tbl_filter(fun.bind(match_window, opts.match), windows)

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

-- Delete all hidden buffers. Returns `false` on failure.
-- `opts` should have the same format as `config.delete_hidden_buffers`.
function M.delete_hidden_buffers(opts)
    local visible = utils.list_to_set(vim.tbl_map(vim.api.nvim_win_get_buf, vim.api.nvim_list_wins()))
    local hidden = vim.tbl_filter(utils.getter(visible), vim.api.nvim_list_bufs())

    for _, buf in ipairs(hidden) do
        if not pcall(vim.api.nvim_buf_delete, buf, { force = opts.force }) then
            vim.notify(
                string.format('Cannot delete buffer with unsaved changes: "%s"', vim.api.nvim_buf_get_name(buf)),
                vim.log.levels.ERROR
            )
            return false
        end
    end

    return true
end

-- Run all the cleanup for a given hook
function M.run(hook)
    local order = {
        { config.close_windows, M.close_windows },
        { config.delete_hidden_buffers, M.delete_hidden_buffers },
    }

    for _, call in ipairs(order) do
        local opts, fn = unpack(call)
        if vim.tbl_contains(opts.hooks, hook) then
            if not fn(opts) then
                return false
            end
        end
    end

    return true
end

return M
