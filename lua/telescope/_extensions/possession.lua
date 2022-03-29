local telescope = require('telescope')
local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')

local session = require('possession.session')

local ns = vim.api.nvim_create_namespace('possession.telescope')

local function split_lines(s, trimempty)
    return vim.split(s, '\n', { plain = true, trimempty = trimempty })
end

-- FIXME: This seems hacky as hell and will most likely break some day...
-- Get the lua parser for given buffer and replace its injection query
-- with one that will make it highlight vimscript inside the string stored
-- in the`vimscript` variable.
local function patch_treesitter_injections(buf)
    local parser = vim.treesitter.get_parser(buf, 'lua')
    local new_query = vim.treesitter.parse_query(
        'lua',
        [[
        (assignment_statement
            (variable_list (identifier) @_vimscript_identifier)
            (expression_list (string content: _ @vim)
            (#eq? @_vimscript_identifier "vimscript")))
    ]]
    )
    parser._injection_query = new_query
end

-- Hacky way to easily get highlighting - just format everything as valid Lua code.
local function display_session_entry(buf, entry)
    local lines = {}

    table.insert(lines, 'name = ' .. vim.inspect(entry.value.name))
    table.insert(lines, '_file = ' .. vim.inspect(entry.value._file))
    table.insert(lines, 'cwd = ' .. vim.inspect(entry.value.cwd))
    table.insert(lines, '')

    local user_data = vim.inspect(entry.value.user_data, { indent = '    ' })
    user_data = split_lines(user_data)
    table.insert(lines, 'user_data = ' .. user_data[1])
    for i = 2, #user_data do
        table.insert(lines, user_data[i])
    end

    table.insert(lines, '')
    table.insert(lines, 'vimscript = [[')
    local vimscript = split_lines(entry.value.vimscript, true)
    vimscript = vim.tbl_map(function(line)
        return '    ' .. line
    end, vimscript)
    vim.list_extend(lines, vimscript)
    table.insert(lines, ']]')

    vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')

    -- Try to add vimscript injections
    local ok = pcall(patch_treesitter_injections, buf)
    if not ok then
        print('WARNING: adding treesitter injections in preview window failed')
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

local function session_previewer(opts)
    opts = opts or {}
    return previewers.new_buffer_previewer {
        title = 'Session Preview',
        teardown = function(self)
            if self.state and self.state.last_set_bufnr and vim.api.nvim_buf_is_valid(self.state.last_set_bufnr) then
                pcall(vim.api.nvim_buf_clear_namespace, self.state.last_set_bufnr, ns, 0, -1)
            end
        end,

        get_buffer_by_name = function(_, entry)
            return entry.value.name
        end,

        define_preview = function(self, entry, status)
            if self.state.last_set_bufnr then
                pcall(vim.api.nvim_buf_clear_namespace, self.state.last_set_bufnr, ns, 0, -1)
            end

            if self.state.bufname ~= entry.value.name then
                display_session_entry(self.state.bufnr, entry)
            end

            self.state.last_set_bufnr = self.state.bufnr
        end,
    }
end

-- Provide some default "mappings"
local default_actions = {
    save = 'select_horizontal',
    load = 'select_vertical',
    delete = 'select_tab',
}

local function list_sessions(opts)
    opts = vim.tbl_extend('force', {
        default_action = 'load',
    }, opts or {})

    assert(
        default_actions[opts.default_action],
        string.format('Supported "default_action" values: %s', vim.tbl_keys(default_actions))
    )

    local sessions = {}
    for file, data in pairs(session.list()) do
        data._file = file
        table.insert(sessions, data)
    end
    table.sort(sessions, function(a, b)
        return a.name < b.name
    end)

    pickers.new(opts, {
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
                        vim.notify('Nothing currently selected', vim.log.levels.WARN)
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
    }):find()
end

return telescope.register_extension {
    exports = {
        possession = list_sessions,
    },
}
