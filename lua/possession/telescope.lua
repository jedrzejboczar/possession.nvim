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

  local get_sessions = function()
    return opts.sessions and vim.list_slice(opts.sessions) or query.as_list()
  end
  local sessions = get_sessions()

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
        attach_mappings = function(prompt_buf, map)
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            if not entry then
              utils.warn('Nothing currently selected')
              return
            end
            actions.close(prompt_buf)
            session[opts.default_action](entry.value.name)
          end)

          local refresh_sessions = function()
            local picker = action_state.get_current_picker(prompt_buf)
            local finder = finders.new_table {
              results = get_sessions(),
              entry_maker = function(entry)
                return {
                  value = entry,
                  display = entry.name,
                  ordinal = entry.name,
                }
              end,
            }

            picker:refresh(finder, { reset_prompt = true })
          end

          local delete_session = function()
            local entry = action_state.get_selected_entry()
            if not entry then
              utils.warn('Nothing currently selected')
              return
            end
            session.delete(entry.value.name, { no_confirm = true })
            refresh_sessions()
          end

          local rename_session = function()
            local entry = action_state.get_selected_entry()
            if not entry then
              utils.warn('Nothing currently selected')
              return
            end
            local new_name = vim.fn.input('New session name: ')
            session.rename(entry.value.name, new_name)
            refresh_sessions()
          end

          map('n', 'd', delete_session)
          map('n', 'r', rename_session)

          map('i', '<c-d>', delete_session)
          map('i', '<c-r>', rename_session)

          return true
        end,
      })
      :find()
end

return M
