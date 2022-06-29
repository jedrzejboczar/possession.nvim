local config = require('possession.config')
local session = require('possession.session')

local function define_commands(defs)
    for name, parts in pairs(defs) do
        if name then
            assert(#parts == 2, 'Should be a tuple {args, cmd}')
            local args, cmd = unpack(parts)
            vim.cmd(string.format('command! %s %s %s', args, name, cmd))
        end
    end
end

local function setup(opts)
    config.setup(opts)

    -- Note that single quotes must be used
    local complete_session = "v:lua.require'possession.commands'.complete_session"

    if config.commands then
        local with_name = '-nargs=? -complete=customlist,' .. complete_session
        define_commands {
            [config.commands.save] = {
                with_name .. ' -bang',
                'lua require("possession.commands").save(<q-args>, "<bang>" == "!")',
            },
            [config.commands.load] = {
                with_name,
                'lua require("possession.commands").load(<f-args>)',
            },
            [config.commands.close] = {
                '-nargs=0 -bang',
                'lua require("possession.commands").close("<bang>" == "!")',
            },
            [config.commands.delete] = {
                with_name .. ' -bang',
                'lua require("possession.commands").delete(<q-args>, "<bang>" == "!")',
            },
            [config.commands.show] = {
                with_name,
                'lua require("possession.commands").show(<f-args>)',
            },
            [config.commands.list] = {
                '-nargs=0 -bang',
                'lua require("possession.commands").list("<bang>" == "!")',
            },
            [config.commands.migrate] = {
                '-nargs=1 -complete=file',
                'lua require("possession.commands").migrate(<f-args>)',
            },
        }
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
