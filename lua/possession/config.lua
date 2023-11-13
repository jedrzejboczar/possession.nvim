local M = {}

local Path = require('plenary.path')

-- Use a function to always get a new table, even if some deep field is modified,
-- like `config.commands.save = ...`. Returning a "constant" still seems to allow
-- the LSP completion to work.
local function defaults()
    -- stylua: ignore
    return {
        session_dir = (Path:new(vim.fn.stdpath('data')) / 'possession'):absolute(),
        silent = false,
        load_silent = true,
        debug = false,
        logfile = false,
        prompt_no_cr = false,
        autosave = {
            current = false,  -- or fun(name): boolean
            tmp = false,  -- or fun(): boolean
            tmp_name = 'tmp', -- or fun(): string
            on_load = true,
            on_quit = true,
        },
        commands = {
            save = 'PossessionSave',
            load = 'PossessionLoad',
            rename = 'PossessionRename',
            close = 'PossessionClose',
            delete = 'PossessionDelete',
            show = 'PossessionShow',
            list = 'PossessionList',
            migrate = 'PossessionMigrate',
        },
        hooks = {
            before_save = function(name) return {} end,
            after_save = function(name, user_data, aborted) end,
            before_load = function(name, user_data) return user_data end,
            after_load = function(name, user_data) end,
        },
        plugins = {
            close_windows = {
                hooks = {'before_save', 'before_load'},
                preserve_layout = true,  -- or fun(win): boolean
                match = {
                    floating = true,
                    buftype = {},
                    filetype = {},
                    custom = false,  -- or fun(win): boolean
                },
            },
            delete_hidden_buffers = {
                hooks = {
                    'before_load',
                    vim.o.sessionoptions:match('buffer') and 'before_save',
                },
                force = false,  -- or fun(buf): boolean
            },
            nvim_tree = true,
            neo_tree = true,
            symbols_outline = true,
            tabby = true,
            dap = true,
            dapui = true,
            delete_buffers = false,
        },
        telescope = {
            previewer = {
                enabled = true,
                previewer = 'pretty', -- or 'raw' or fun(opts): Previewer
                wrap_lines = true,
                include_empty_plugin_data = false,
            },
            list = {
                default_action = 'load',
                mappings = {
                    save = { n = '<c-x>', i = '<c-x>' },
                    load = { n = '<c-v>', i = '<c-v>' },
                    delete = { n = '<c-t>', i = '<c-t>' },
                    rename = { n = '<c-r>', i = '<c-r>' },
                },
            },
        },
    }
end

local config = defaults()

-- Keys that cannot be checked automatically because they are nil by default
local nil_keys = {
    ['telescope.previewer'] = true,
}

local function warn_on_unknown_keys(conf)
    local unknown = {}

    local function traverse(c, ref, state)
        state = state or {
            path = '',
            max_depth = 8,
        }

        if state.max_depth <= 0 then
            return
        end

        for key, val in pairs(c) do
            -- ignore list-like tables
            if type(key) == 'string' then
                if ref == nil or ref[key] == nil then
                    local path = state.path .. key
                    if ref[key] == nil and not nil_keys[path] then
                        table.insert(unknown, path)
                    end
                elseif type(val) == 'table' then
                    traverse(val, ref[key], {
                        path = state.path .. key .. '.',
                        max_depth = state.max_depth - 1,
                    })
                end
            end
        end
    end

    traverse(conf, defaults())

    if #unknown > 0 then
        vim.schedule(function()
            vim.notify(
                'Unknown keys passed to possession.setup:\n  ' .. table.concat(unknown, '\n  '),
                vim.log.levels.WARN
            )
        end)
    end
end

local function fix_compatibility(opts)
    if type(vim.tbl_get(opts, 'telescope', 'previewer')) == 'boolean' then
        opts.telescope.previewer = {
            enable = opts.telescope.previewer,
        }
    end
end

function M.setup(opts)
    warn_on_unknown_keys(opts)

    fix_compatibility(opts)

    local new_config = vim.tbl_deep_extend('force', {}, defaults(), opts or {})
    -- Do _not_ replace the table pointer with `config = ...` because this
    -- wouldn't change the tables that have already been `require`d by other
    -- modules. Instead, clear all the table keys and then re-add them.
    for _, key in ipairs(vim.tbl_keys(config)) do
        config[key] = nil
    end
    for key, val in pairs(new_config) do
        config[key] = val
    end
end

-- Return the config table (getting completion!) but fall back to module methods.
return setmetatable(config, { __index = M })
