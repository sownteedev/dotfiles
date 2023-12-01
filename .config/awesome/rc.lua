pcall(require, "luarocks.loader")
require("awful.autofocus")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")

naughty.connect_signal("request::display_error", function(message, startup)
	naughty.notification {
		urgency = "critical",
		title = "Oops, an error happened" .. (startup and " during startup!" or "!"),
		message = message
	}
end)

awful.spawn.with_shell("~/.config/awesome/start")
beautiful.init("~/.config/awesome/themes/theme.lua")

require("config")
require("modules")
require("ui")
