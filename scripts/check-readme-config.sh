#!/usr/bin/env bash
# Check if the defaults from config.lua are the same in README.md
# Poor but simple implementation based on sed and other standard tools.

defaults_file="$1"
readme_file="$2"

from_line() {
    tail -n "+$1"
}

ignore_last() {
    head -n "-$1"
}

remove_indent() {
    # 4 spaces
    sed 's/^    //'
}

# Retrieve the defaults table from config.lua
# 1. Get lines of the defaults() function (including start/end)
# 2. Get lines since return to end
# 3. Remove the "return" line
# 4. Remove "}\nend" (2 lines)
config=$(
    sed -n '/^local function defaults/,/^end/ p' "$defaults_file" \
        | sed -n '/^\s*return/,$ p' \
        | from_line 2 \
        | ignore_last 2 \
        | remove_indent
)

config_section() {
    sed -n '/^## Configuration/,/^##/ p'
}

code_block() {
    sed -n '/^```lua$/,/^```$/ p'
}

# Get defaults from README
# 1. Lines of the Configuration section
# 2. Lines of the lua code block
# 3. Remove starting lines in code block
# 4. Remove ending lines in code block
readme_config=$(
    sed -n '/^## Configuration/,/^##/ p' "$readme_file" \
        | sed -n '/^```lua$/,/^```$/ p' \
        | from_line 3 \
        | ignore_last 2
)

diff <(echo "$config") <(echo "$readme_config")
# echo "$config"
