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

        -- Delete old symlink that is not used anymore
        -- TODO: remove when we explicitly drop support for nvim <0.10 which does not have vim.fs.joinpath
        if vim.tbl_get(vim, 'fs', 'joinpath') then
            local symlink = vim.fs.joinpath(config.session_dir, '__last__')
            vim.fn.delete(symlink)
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
