local M = {}

local utils = require('possession.utils')

function M.before_load(_, _, plugin_data)
    utils.stop_lsp_clients()
    return plugin_data
end

return M
