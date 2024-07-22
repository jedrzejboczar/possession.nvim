local telescope = require('telescope')
local pickers = require('possession.telescope')

return telescope.register_extension {
    exports = {
        list = pickers.list,
        possession = pickers.list,
    },
}
