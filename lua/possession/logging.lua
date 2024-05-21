local M = {}

local Path = require('plenary.path')
local config = require('possession.config')

local log_date_format = '%F %H:%M:%S'
local log_levels = vim.deepcopy(vim.log.levels)
for k, v in pairs(log_levels) do
    log_levels[v] = k
end

local logfile
local get_logfile_done = false

-- Called on first log
local function get_logfile()
    if get_logfile_done then
        return logfile
    end
    get_logfile_done = true

    if not config.logfile then
        return
    end

    -- Use default name
    local filename = config.logfile
    if type(filename) ~= 'string' then
        filename = (Path:new(vim.fn.stdpath('log')) / 'possession.log'):absolute()
    end

    local file, err = io.open(filename, 'a+')
    if not file then
        M.error('Possession: could not open logfile "%s": %s', filename, err)
        return
    end

    file:write(string.format('\n[%s][START] Logging started\n', os.date(log_date_format)))

    logfile = file
    return logfile
end

---@param msg string
---@param level integer
function M.to_file(msg, level)
    local file = get_logfile()
    if file then
        local header = string.format('[%s][%s] ', os.date(log_date_format), log_levels[level])
        file:write(header, msg, '\n')
        file:flush()
    end
end

---@param msg string
---@param level integer
function M.to_all(msg, level)
    vim.notify(msg, level)
    M.to_file(msg, level)
end

return M
