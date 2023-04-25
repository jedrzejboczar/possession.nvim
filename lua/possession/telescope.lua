local M = {}

local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')

local session = require('possession.session')
local display = require('possession.display')
local query = require('possession.query')
local utils = require('possession.utils')

local function session_previewer(opts)
    return previewers.new_buffer_previewer {
        title = 'Session Preview',
        get_buffer_by_name = function(_, entry)
            return entry.value.name
        end,
        define_preview = function(self, entry, status)
            if self.state.bufname ~= entry.value.name then
                display.in_buffer(entry.value, self.state.bufnr)
            end
        end,
    }
end

-- Provide some default "mappings"
local default_actions = {
    save = 'select_horizontal',
    load = 'select_vertical',
    delete = 'select_tab',
}

---@class possession.TelescopeListOpts
---@param default_action? 'load'|'save'|'delete'
---@param sessions? table[] list of sessions like returned by query.as_list
---@param sort? boolean|possession.QuerySortKey sort the initial sessions list, `true` means 'mtime'

---@param opts possession.TelescopeListOpts
function M.list(opts)
    opts = vim.tbl_extend('force', {
        default_action = 'load',
        sessions = nil,
        sort = 'mtime',
    }, opts or {})

    assert(
        default_actions[opts.default_action],
        string.format('Supported "default_action" values: %s', vim.tbl_keys(default_actions))
    )

    local sessions = opts.sessions and vim.list_slice(opts.sessions) or query.as_list()
    if opts.sort then
        local key = opts.sort == true and 'name' or opts.sort
        local descending = key ~= 'name'
        query.sort_by(sessions, key, descending)
    end

    pickers
        .new(opts, {
            prompt_title = 'Sessions',
            finder = finders.new_table {
                results = sessions,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.name,
                        ordinal = entry.name,
                    }
                end,
            },
            sorter = conf.generic_sorter(opts),
            previewer = session_previewer(opts),
            attach_mappings = function(buf)
                local attach = function(telescope_act, fn)
                    actions[telescope_act]:replace(function()
                        local entry = action_state.get_selected_entry()
                        if not entry then
                            utils.warn('Nothing currently selected')
                            return
                        end
                        actions.close(buf)
                        fn(entry.value.name)
                    end)
                end

                attach('select_default', session[opts.default_action])
                for fn_name, action in pairs(default_actions) do
                    attach(action, session[fn_name])
                end

                return true
            end,
        })
        :find()
end

return M
