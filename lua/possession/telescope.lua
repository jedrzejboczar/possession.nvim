local M = {}

local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local transform_mod = require('telescope.actions.mt').transform_mod

local config = require('possession.config')
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
            local wrap = config.telescope.previewer.wrap_lines
            if wrap == true and vim.api.nvim_win_is_valid(self.state.winid) then
                vim.api.nvim_win_set_option(self.state.winid, 'wrap', true)
            end
            if self.state.bufname ~= entry.value.name then
                display.in_buffer(entry.value, self.state.bufnr, config.telescope.previewer.previewer, {
                    include_empty_plugin_data = config.telescope.previewer.include_empty_plugin_data,
                })
            end
        end,
    }
end

-- Perform given action, close prompt_buf manually if needed
local session_actions = {
    save = function(prompt_buf, entry, _refresh)
        actions.close(prompt_buf)
        session.save(entry.value.name)
    end,
    load = function(prompt_buf, entry, _refresh)
        actions.close(prompt_buf)
        -- For some reason telescope stays in insert mode (#46)
        vim.cmd.stopinsert()
        session.load(entry.value.name)
    end,
    delete = function(prompt_buf, entry, refresh)
        session.delete(entry.value.name, { callback = refresh })
    end,
    rename = function(prompt_buf, entry, refresh)
        local opts = { prompt = 'New session name: ', default = entry.value.name }
        vim.ui.input(opts, function(new_name)
            if new_name then
                session.rename(entry.value.name, new_name)
                refresh()
            end
        end)
    end,
}

---@class possession.TelescopeListOpts
---@field default_action? 'load'|'save'|'delete'
---@field sessions? table[] list of sessions like returned by query.as_list
---@field sort? boolean|possession.QuerySortKey sort the initial sessions list, `true` means 'mtime'

---@param opts possession.TelescopeListOpts
function M.list(opts)
    opts = vim.tbl_extend('force', {
        default_action = 'load',
        sessions = nil,
        sort = 'mtime',
    }, opts or {})

    assert(
        session_actions[opts.default_action],
        string.format('Supported "default_action" values: %s', vim.tbl_keys(session_actions))
    )

    local get_finder = function()
        local sessions = opts.sessions and vim.list_slice(opts.sessions) or query.as_list()
        if opts.sort then
            local key = opts.sort == true and 'name' or opts.sort
            local descending = key ~= 'name'
            query.sort_by(sessions, key, descending)
        end
        return finders.new_table {
            results = sessions,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name,
                    ordinal = entry.name,
                }
            end,
        }
    end

    local previewer
    if config.telescope.previewer.enabled == false then
        previewer = false
    elseif type(config.telescope.previewer.previewer) == 'function' then
        previewer = config.telescope.previewer.previewer(opts)
    else
        previewer = session_previewer(opts)
    end

    pickers
        .new(opts, {
            prompt_title = 'Sessions',
            finder = get_finder(),
            sorter = conf.generic_sorter(opts),
            previewer = previewer,
            attach_mappings = function(prompt_buf, map)
                local refresh = function()
                    local picker = action_state.get_current_picker(prompt_buf)
                    picker:refresh(get_finder(), { reset_prompt = true })
                end

                local action_fn = function(act)
                    return function()
                        local entry = action_state.get_selected_entry()
                        if not entry then
                            utils.warn('Nothing currently selected')
                            return
                        end
                        if session_actions[act](prompt_buf, entry, refresh) then
                            refresh()
                        end
                    end
                end

                actions.select_default:replace(action_fn(opts.default_action))

                -- Define actions such that names will be visible in which key (after pressing "?")
                local actions_mod = {}
                for name, _ in pairs(session_actions) do
                    local key = 'session_' .. name
                    actions_mod[key] = action_fn(name)
                end
                actions_mod = transform_mod(actions_mod)

                for name, _ in pairs(session_actions) do
                    local mappings = config.telescope.list.mappings[name]
                    if type(mappings) == 'string' then
                        mappings = { i = mappings, n = mappings }
                    end
                    local key = 'session_' .. name
                    map('n', mappings.n, actions_mod[key])
                    map('i', mappings.i, actions_mod[key])
                end

                return true
            end,
        })
        :find()
end

return M
