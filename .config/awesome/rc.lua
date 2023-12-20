pcall(require, "luarocks.loader")
require("awful.autofocus")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

awful.spawn.with_shell("~/.config/awesome/config/autostart")
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/theme.lua")

local naughty = require "naughty"
naughty.connect_signal("request::display_error", function(message, startup)
	naughty.notification {
		urgency = "critical",
		title   = "Oops, an error happened" .. (startup and " during startup!" or "!"),
		message = message
	}
end)

require("config")
require("ui")
