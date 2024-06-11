local group = vim.api.nvim_create_augroup('Possession', {})

vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    group = group,
    callback = function()
        if require('possession.config').autosave.on_quit then
            require('possession.session').autosave()
        end
    end,
})

vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    nested = true, -- to correctly setup buffers
    callback = function()
        -- Be lazy when loading modules
        local config = require('possession.config')
        local Path = require('plenary.path')

        local symlink = Path:new(config.session_dir) / '__last__'
        if symlink:exists() then
            symlink:rm()
        end

        local utils = require('possession.utils')
        if utils.as_function(config.autoload.cwd)() then
            local paths = require('possession.paths')
            local cwd = paths.cwd_session_name()
            if paths.session(cwd):exists() then
                utils.debug('Auto-loading CWD session: %s', cwd)
                require('possession.session').load(cwd)
            end
        end
    end,
})
