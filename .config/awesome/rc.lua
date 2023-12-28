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

gears.timer {
	timeout = 5,
	autostart = true,
	call_now = true,
	callback = function()
		collectgarbage "collect"
	end,
}

collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
