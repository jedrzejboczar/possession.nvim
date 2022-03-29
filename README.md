# possession.nvim

Flexible session management for Neovim.

## Features:

* Save/load Vim sessions
* Keep track of last used session
* Sessions stored in JSON files
* Store arbitrary data in the session file
* User hooks before/after save/load
* Uses good old `:mksession` under the hood
* Out of the box [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) integration

## About

This is yet another session management plugin for Neovim.

The main goal was to make session management more flexible and overall more
Lua-friendly. All other session management plugins I know
(e.g. [auto-session](https://github.com/rmagatti/auto-session),
[persisted.nvim](https://github.com/olimorris/persisted.nvim),
[vim-obsession](https://github.com/tpope/vim-obsession),
[vim-startify](https://github.com/mhinz/vim-startify))
use Vim's `:mksession!` directly to generate Vimscript files that are later `:source`d.
This works well in general, but storing user data between sessions may be problematic.

To solve this issue `possession` uses JSON files to easily store session metadata.
Under the hood `:mksession!` is still used, but the resulting Vimscript is stored
in the JSON file along other data.

## Installation

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'jedrzejboczar/possession.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
}
```

Or with other package managers/manually, but make sure
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is installed.

## Configuration

Call `require('possession').setup { ... }` somewhere in your `init.lua`.
See [doc/possession.txt](./doc/possession.txt) for details, the default configuartion is:

```lua
require('possession').setup {
    session_dir = (Path:new(vim.fn.stdpath('data')) / 'possession'):absolute(),
    silent = false,
    commands = {
        save = 'PossessionSave',
        load = 'PossessionLoad',
        delete = 'PossessionDelete',
        show = 'PossessionShow',
        list = 'PossessionList',
    },
    hooks = {
        before_save = function(name) return {} end,
        after_save = function(name, user_data, aborted) end,
        before_load = function(name, user_data) return user_data end,
        after_load = function(name, user_data) end,
    },
    close_windows = {
        hooks = {'before_save', 'before_load'},
        preserve_layout = true,  -- or fun(win): boolean
        match = {
            floating = true,
            buftype = {},
            filetype = {},
            custom = false,  -- or fun(win): boolean
        },
    },
    delete_hidden_buffers = {
        hooks = {
            'before_load',
            vim.o.sessionoptions:match('buffer') and 'before_save',
        },
        force = false,
    },
}
```


## Recommendations

### Commands

The defaults command names are quite long, but shorter names can be configured:

```lua
require('possession').setup {
    commands = {
        save = 'SSave',
        load = 'SLoad',
        delete = 'SDelete',
        list = 'SList',
    }
}
```

### Telescope

```lua
require('telescope').load_extension('possession')
```

Then use `:Telescope possession list` or `require('telescope').extensions.possession.list()`


### Session options

Under the hood this plugin uses the command `:mksession` which in turn uses `'sessionoptions'`
to "make" the session. See `:help 'sessionoptions'` for available options, some notable ones:

* `options` - Can mess things up, use only when you know what you're doing (Neovim has sane
  default of *not* including this one)
* `buffers` - While this plugin offers `delete_hidden_buffers`, I'd also suggest using
  `set sessionoptions-=buffers` to just exclude hidden buffers when saving session.
