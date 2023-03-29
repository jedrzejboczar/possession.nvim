local config = require('possession.config')
local session = require('possession.session')

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
        cmd(names.migrate, 'dir_or_file', { nargs = 1, complete = 'file' }, function(o)
            commands.migrate(o.fargs[1])
        end)
    end
end

return {
    setup = setup,
    save = session.save,
    load = session.load,
    delete = session.delete,
    show = session.show,
    list = session.list,
    last = session.last,
}
