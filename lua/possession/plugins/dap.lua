local M = {}

local utils = require('possession.utils')

local has_plugin = pcall(require, 'dap')

function M.before_save(opts, name)
    if not has_plugin then
        return {}
    end

    -- For now only a list of { filename = X, line = Y }
    local breakpoints = {}

    for buf, buf_breakpoints in pairs(require('dap.breakpoints').get()) do
        for _, breakpoint in ipairs(buf_breakpoints) do
            local fname = vim.api.nvim_buf_get_name(buf)
            table.insert(breakpoints, {
                filename = fname,
                line = breakpoint.line,
            })
        end
    end

    return {
        breakpoints = breakpoints,
    }
end

function M.after_load(opts, name, plugin_data)
    if not has_plugin then
        return
    end

    local cur_buf = vim.api.nvim_get_current_buf()
    local bufs_by_name = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        bufs_by_name[vim.api.nvim_buf_get_name(buf)] = buf
    end

    for _, breakpoint in ipairs(plugin_data.breakpoints or {}) do
        local buf = bufs_by_name[breakpoint.filename]
        if not buf then
            -- quickly load and restore
            local ok = pcall(vim.api.nvim_cmd, { cmd = 'edit', args = { breakpoint.filename } })
            if ok then
                buf = vim.api.nvim_get_current_buf()
            end
        end
        if buf and vim.api.nvim_buf_is_valid(buf) then
            local bopts = {} -- TODO: conditions etc.
            require('dap.breakpoints').set(bopts, buf, breakpoint.line)
            utils.debug('Restoring breakpoint at %s:%s', breakpoint.filename, breakpoint.line)
        else
            utils.warn('Could not restore breakpoint at %s:%s', breakpoint.filename, breakpoint.line)
        end
    end

    -- Go back to the correct buffer
    vim.api.nvim_set_current_buf(cur_buf)
end

return M
