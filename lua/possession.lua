local config = require('possession.config')
local session = require('possession.session')

local function define_commands(defs)
    for name, parts in pairs(defs) do
        assert(#parts == 2, 'Should be a tuple {args, cmd}')
        local args, cmd = unpack(parts)
        vim.cmd(string.format('command! %s %s %s', args, name, cmd))
    end
end

local function setup(opts)
    config.setup(opts)

    -- Note that single quotes must be used
    local complete_session = "v:lua.require'possession.commands'.complete_session"

    define_commands {
        [config.commands.save] = {
            '-nargs=? -bang -complete=customlist,' .. complete_session,
            'lua require("possession.commands").save(<f-args>, "<bang>" == "!")',
        },
        [config.commands.load] = {
            '-nargs=? -complete=customlist,' .. complete_session,
            'lua require("possession.commands").load(<f-args>)',
        },
        [config.commands.delete] = {
            '-nargs=? -complete=customlist,' .. complete_session,
            'lua require("possession.commands").delete(<f-args>)',
        },
        [config.commands.list] = {
            '-nargs=0 -bang',
            'lua require("possession.commands").list("<bang>" == "!")',
        },
    }
end

return {
    setup = setup,
    save = session.save,
    load = session.load,
    delete = session.delete,
    list = session.list,
}
