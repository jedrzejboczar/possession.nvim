local M = {}

local utils = require('possession.utils')

function M.before_load(_, _, plugin_data)
    utils.delete_all_buffers(true)
    return plugin_data
end

return M
