pcall(require, "luarocks.loader")
local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")

awful.spawn.with_shell("picom --config ~/.config/bspwm/config/picom.conf &")
awful.spawn.with_shell("dunst -config ~/.config/bspwm/config/dunstrc &")
awful.spawn.with_shell("feh -z --no-fehbg --bg-fill ~/.walls")
awful.spawn.with_shell("xss-lock -- betterlockscreen -l dimblur &")
beautiful.init("~/.config/awesome/theme/theme.lua")

require("config")
require("ui")
