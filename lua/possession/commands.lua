local M = {}

local session = require('possession.session')
local utils = require('possession.utils')

local function complete_list(candidates, opts)
    opts = vim.tbl_extend('force', {
        sort = true,
    }, opts or {})

    vim.validate { candidates = { candidates, { 'table', 'function' } } }

    local get_candidates = function()
        local list = type(candidates) == 'function' and candidates() or candidates
        if opts.sort then
            table.sort(list)
        end
        return list
    end

    return function(arg_lead, cmd_line, cursor_pos)
        return vim.tbl_filter(function(c)
            return vim.startswith(c, arg_lead)
        end, get_candidates())
    end
end

-- Limits filesystem access by caching the results by time
M.complete_session = complete_list(utils.throttle(function()
    local files = vim.tbl_keys(session.list { no_read = true })
    return vim.tbl_map(utils.session_name_from_path, files)
end, 3000))

function M.save(name, no_confirm)
    session.save(name, { no_confirm = no_confirm })
end

function M.load(name)
    session.load(name)
end

function M.delete(name)
    session.delete(name)
end

function M.list(full)
    local sessions = session.list()
    if not full then
        for _, data in pairs(sessions) do
            data.vimscript = nil
        end
    end
    print(vim.inspect(sessions, { indent = '    ' }))
end

return M
