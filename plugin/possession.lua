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
        local al = utils.as_function(config.autoload)()
        if al and al ~= '' then
            local cmd = require('possession.commands')
            local session = cmd.load_last(al)
            if session then
                utils.debug('Auto-loading session: %s', session)
            end
        end
    end,
})
