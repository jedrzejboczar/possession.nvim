local config = require('possession.config')

local function cmd(name, args_desc, opts, cb)
    local desc = name .. ' ' .. args_desc
    opts = vim.tbl_extend('force', { desc = desc }, opts)
    vim.api.nvim_create_user_command(name, cb, opts)
end

local function setup(opts)
    config.setup(opts)

    if config.commands then
        local names = config.commands
        local commands = require('possession.commands')
        local complete = commands.complete_session

        cmd(names.save, 'name?', { nargs = '?', complete = complete, bang = true }, function(o)
            commands.save(o.fargs[1], o.bang)
        end)
        cmd(names.load, 'name?', { nargs = '?', complete = complete }, function(o)
            commands.load(o.fargs[1])
        end)
        cmd(names.save_cwd, '', { nargs = 0, bang = true }, function(o)
            commands.save_cwd(o.bang)
        end)
        cmd(names.load_cwd, '', { nargs = 0 }, function(_)
            commands.load_cwd()
        end)
        cmd(names.rename, 'old_name? new_name?', { nargs = '*', complete = complete }, function(o)
            commands.rename(o.fargs[1], o.fargs[2])
        end)
        cmd(names.close, '', { nargs = 0, bang = true }, function(o)
            commands.close(o.bang)
        end)
        cmd(names.delete, 'name?', { nargs = '?', complete = complete }, function(o)
            commands.delete(o.fargs[1])
        end)
        cmd(names.show, 'name?', { nargs = '?', complete = complete }, function(o)
            commands.show(o.fargs[1])
        end)
        cmd(names.list, '', { nargs = 0, bang = true }, function(o)
            commands.list(o.bang)
        end)
        cmd(names.list_cwd, 'dir?', { nargs = '?', complete = 'dir', bang = true }, function(o)
            commands.list_cwd(o.fargs[1], o.bang)
        end)
        cmd(names.migrate, 'dir_or_file', { nargs = 1, complete = 'file' }, function(o)
            commands.migrate(o.fargs[1])
        end)
    end

    local function set_hl(name, color)
        local val = { default = true }
        if vim.startswith(color, '#') then
            val.fg = color
        else
            val.link = color
        end
        vim.api.nvim_set_hl(0, name, val)
    end

    set_hl('PossessionPreviewCwd', config.telescope.previewer.cwd_colors.cwd)
    for i, color in ipairs(config.telescope.previewer.cwd_colors.tab_cwd) do
        set_hl(string.format('PossessionPreviewTabCwd%d', i), color)
    end
end

local function lazy(mod, func)
    return function(...)
        return require(mod)[func](...)
    end
end

return {
    setup = setup,
    save = lazy('possession.session', 'save'),
    load = lazy('possession.session', 'load'),
    delete = lazy('possession.session', 'delete'),
    show = lazy('possession.session', 'show'),
    list = lazy('possession.session', 'list'),
    last = lazy('possession.session', 'last'),
}
