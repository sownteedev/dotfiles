local awful = require("awful")
local naughty = require("naughty")
local menubar = require("menubar")
local beautiful = require("beautiful")

naughty.connect_signal("request::icon", function(n, context, hints)
	if context ~= "app_icon" then
		return
	end
	local path = menubar.utils.lookup_icon(hints.app_icon) or menubar.utils.lookup_icon(hints.app_icon:lower())
	if path then
		n.icon = path
	end
end)

-- naughty config
naughty.config.defaults.position = "bottom_right"
naughty.config.defaults.timeout = 10
naughty.config.defaults.title = "Ding!"
naughty.config.defaults.screen = awful.screen.focused()
beautiful.notification_spacing = 20

-- Timeouts
naughty.config.presets.low.timeout = 10
naughty.config.presets.critical.timeout = 0

naughty.connect_signal("request::display", function(n)
	require("widgets.notification")(n)
end)
