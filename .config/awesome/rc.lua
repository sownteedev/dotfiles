pcall(require, "luarocks.loader")
require("awful.autofocus")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

awful.spawn.with_shell("~/.config/awesome/config/autostart")
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/theme.lua")
require("themes.toggle")

require("config")
require("signals")
require("ui")
