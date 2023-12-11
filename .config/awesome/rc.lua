pcall(require, "luarocks.loader")
require("awful.autofocus")
local awful = require("awful")
local beautiful = require("beautiful")

awful.spawn.with_shell("~/.config/awesome/autostart")
beautiful.init("~/.config/awesome/themes/theme.lua")

require("config")
require("modules")
require("ui")
