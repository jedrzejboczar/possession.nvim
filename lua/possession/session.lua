local M = {}

local Path = require('plenary.path')
local config = require('possession.config')
local utils = require('possession.utils')
local plugins = require('possession.plugins')
local paths = require('possession.paths')

M.session_name = nil

-- Get last loaded/saved session
--@return string | nil: path to session file
function M.last()
    local link_path = paths.last_session_link()
    local path = vim.loop.fs_readlink(link_path:absolute())
    if not path then
        return nil
    end

    -- Clean up broken link
    path = Path:new(path)
    if not path:exists() then
        link_path:rm()
        return nil
    end

    return path:absolute()
end

-- Save current session
--
--@param vimscript string?: mksession-generated commands, ignore hooks
--@param no_confirm boolean?: do not ask when overwriting existing file
--@param callback function?: called after saving (as vim.ui.input may be async)
--@param cwd string?: force cwd, useful in combination with vimscript
function M.save(name, opts)
    opts = vim.tbl_extend('force', {
        vimscript = nil,
        no_confirm = false,
        callback = nil,
        cwd = nil,
    }, opts or {})

    vim.validate {
        name = { name, 'string' },
        vimscript = { opts.vimscript, utils.is_type { 'nil', 'string' } },
        no_confirm = { opts.no_confirm, 'boolean' },
        callback = { opts.callback, utils.is_type { 'function', 'nil' } },
        cwd = { opts.cwd, utils.is_type { 'string', 'nil' } },
    }

    local vimscript
    local user_data
    local plugin_data

    if opts.vimscript then
        vimscript = opts.vimscript
        user_data = {}
        plugin_data = {}
    else
        -- Get user data to store, abort on false/nil
        user_data = config.hooks.before_save(name)
        if not user_data then
            return
        end

        -- Run plugins
        plugin_data = plugins.before_save(name)
        if not plugin_data then
            return
        end

        vim.api.nvim_exec_autocmds('User', { pattern = 'SessionSavePre' })
        vimscript = M.mksession()
    end

    -- Generate data for serialization
    local session_data = {
        name = name,
        vimscript = vimscript,
        cwd = opts.cwd or vim.fn.getcwd(),
        user_data = user_data,
        plugins = plugin_data,
    }

    -- Write to disk
    local path = paths.session(name)
    local short = paths.session_short(name)
    local commit = function(ok)
        if ok then
            vim.fn.mkdir(config.session_dir, 'p')
            path:write(vim.json.encode(session_data), 'w')

            -- Update link pointing to last session
            M.update_last_session(path)
            M.session_name = name

            utils.info('Saved as "%s"', short)
        else
            utils.info('Aborting')
        end

        if not opts.vimscript then
            plugins.after_save(name, plugin_data, not ok)
            config.hooks.after_save(name, user_data, not ok)
        end

        if opts.callback then
            opts.callback()
        end
    end

    -- ask for user confirmation if required
    if path:exists() and not opts.no_confirm then
        utils.prompt_yes_no(string.format('Overwrite session "%s"?', name), commit)
    else
        commit(true)
    end
end

function M.autosave()
    if M.session_name then
        if utils.as_function(config.autosave.current)(M.session_name) then
            utils.debug('Auto-saving session "%s"', M.session_name)
            M.save(M.session_name, { no_confirm = true })
        end
    elseif utils.as_function(config.autosave.tmp)() then
        -- Save as tmp when session is not loaded

        -- Skip scratch buffer e.g. startscreen
        local unscratch_buffers = vim.tbl_filter(function(buf)
            return 'nofile' ~= vim.api.nvim_buf_get_option(buf, 'buftype')
        end, vim.api.nvim_list_bufs())
        if not unscratch_buffers or not next(unscratch_buffers) then
            return
        end

        utils.debug('Auto-saving tmp session as "%s"', config.autosave.tmp_name)
        M.save(config.autosave.tmp_name, { no_confirm = true })
    end
end

-- Load session by name (or from raw data)
--
--@param name_or_data string|table: name if string, else a table with raw
-- data that will be saved as the session file in JSON format.
function M.load(name_or_data)
    vim.validate { name_or_data = { name_or_data, utils.is_type { 'string', 'table' } } }

    -- Load session data
    local session_data
    local path
    if type(name_or_data) == 'string' then
        path = paths.session(name_or_data)
        session_data = vim.json.decode(path:read())
    else
        session_data = name_or_data
    end

    -- Autosave if not loading the auto-saved session itself
    local tmp_name = utils.as_function(config.autosave.tmp)() and config.autosave.tmp_name
    local autosaved_name = M.session_name or tmp_name
    if config.autosave.on_load and session_data.name ~= autosaved_name then
        M.autosave()
    end

    -- Run pre-load hook that can pre-process user data, abort if returns falsy value.
    local user_data = config.hooks.before_load(session_data.name, session_data.user_data)
    if not user_data then
        return
    end

    -- Run plugins
    local plugin_data = plugins.before_load(session_data.name, session_data.plugins or {})
    if not plugin_data then
        return
    end

    -- Source the Vimscript generated by mksession
    vim.api.nvim_exec(session_data.vimscript, config.load_silent)

    -- Update link pointing to last session if loaded from file
    if path then
        M.update_last_session(path)
    end
    M.session_name = session_data.name

    if session_data.name == config.autosave.tmp_name then
        M.session_name = nil
    else
        M.session_name = session_data.name
    end

    plugins.after_load(session_data.name, plugin_data)
    config.hooks.after_load(session_data.name, user_data)

    utils.info('Loaded session "%s"', session_data.name)
end

-- Close currently open session
--@param force boolean?: delete unsaved buffers
function M.close(force)
    if not M.session_name then
        return
    end

    utils.delete_all_buffers(force)
    M.session_name = nil
end

-- Delete session by name
--@param no_confirm boolean?: do not ask when deleting
--@param callback function?: called after saving (as vim.ui.input may be async)
function M.delete(name, opts)
    opts = vim.tbl_extend('force', {
        no_confirm = false,
        callback = nil,
    }, opts or {})

    vim.validate {
        name = { name, 'string' },
        no_confirm = { opts.no_confirm, 'boolean' },
        callback = { opts.callback, utils.is_type { 'function', 'nil' } },
    }

    local path = paths.session(name)
    local short = paths.session_short(name)

    if not path:exists() then
        utils.warn('Session not exists: "%s"', path:absolute())
        return
    end

    local commit = function(ok)
        if ok then
            if vim.fn.delete(path:absolute()) ~= 0 then
                utils.error('Failed to delete session: "%s"', short)
            else
                if M.session_name == name then
                    M.session_name = nil
                end
                utils.info('Deleted "%s"', short)
            end
        else
            utils.info('Aborting')
        end

        if opts.callback then
            opts.callback()
        end
    end

    -- ask for user confirmation if required
    if not opts.no_confirm then
        utils.prompt_yes_no(string.format('Delete session "%s"?', name), commit)
    else
        commit(true)
    end
end

-- Get a list of sessions as map-like table
--@param no_read boolean?: do not read/parse session files, just scan the directory
--@return table: depending on `no_read` this will be:
--  no_read=false: table of {filename: session_data} for all available sessions
--  no_read=true: table of {filename: true}
function M.list(opts)
    opts = vim.tbl_extend('force', {
        no_read = true,
    }, opts or {})

    local sessions = {}
    local glob = paths.session('*'):absolute()
    for _, file in ipairs(vim.fn.glob(glob, true, true)) do
        local path = Path:new(file)
        local data = opts.no_read and vim.json.decode(path:read()) or path:absolute()
        sessions[file] = data
    end

    return sessions
end

-- Run :mksession! and return output as string by writing to a temporary file
function M.mksession()
    local tmp = vim.fn.tempname()
    vim.cmd('mksession! ' .. tmp)
    return Path:new(tmp):read()
end

-- Change the path to last file (make the symlink point to `path`)
function M.update_last_session(path)
    -- Must unlink if exists because fs_symlink won't overwrite existing links
    local link_path = paths.last_session_link()
    if link_path:exists() then
        link_path:rm()
    end
    vim.loop.fs_symlink(path:absolute(), link_path:absolute())
end

return M
