local M = {}

local Path = require('plenary.path')
local session = require('possession.session')
local paths = require('possession.paths')
local utils = require('possession.utils')

-- Migrate mksession-based file to JSON format by loading and saving the session
function M.migrate(vimscript_path, opts)
    opts = vim.tbl_extend('force', {
        name = nil,
        callback = nil,
    }, opts or {})
    -- If not provided fallback to filename without extension
    local name = opts.name and opts.name or paths.session_name(vimscript_path)
    local vimscript = Path:new(vimscript_path):read()

    -- Try to retrieve cwd from vimscript, fall back to getcwd
    local cwd
    for _, line in ipairs(utils.split_lines(vimscript)) do
        local match = line:match('^cd (.*)$')
        if match then
            cwd = match
            break
        end
    end
    if not cwd then
        vim.notify('Could not retrieve CWD from vimscript - using getcwd()', vim.log.levels.WARN)
        cwd = vim.fn.getcwd()
    end

    session.save(name, {
        vimscript = vimscript,
        cwd = cwd,
        callback = opts.callback,
    })
end

-- Try to migrate directory with vimscript sessions to config.session_dir
function M.migrate_dir(vimscript_dir)
    -- TODO: does it handle path separators correctly
    local glob = vim.fn.expand(vimscript_dir) .. '/*'
    local files = vim.tbl_filter(function(file)
        return vim.fn.getftype(file) == 'file'
    end, vim.fn.glob(glob, true, true))

    -- Be async
    local i = 0
    local migrate_next
    migrate_next = function()
        if i < #files then
            i = i + 1
            M.migrate(files[i], {
                callback = migrate_next,
            })
        end
    end
    migrate_next()
end

return M
