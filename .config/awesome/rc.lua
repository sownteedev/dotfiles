pcall(require, "luarocks.loader")
local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")

awful.spawn.with_shell("~/.config/awesome/start")
beautiful.init("~/.config/awesome/themes/init.lua")

require("config")
require("modules")
require("ui")
