local session = require('possession.session')
local possession_group = vim.api.nvim_create_augroup('Possession', {})

vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    group = possession_group,
    callback = session.autosave,
})
