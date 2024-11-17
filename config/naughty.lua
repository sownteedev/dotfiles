local awful = require("awful")
local naughty = require("naughty")
local beautiful = require("beautiful")

naughty.connect_signal('request::display_error', function(message, startup)
	naughty.notification({
		urgency  = 'critical',
		app_name = "Awesome",
		title    = _Utils.widget.colorizeText('Oops, an error happened' .. (startup and ' during startup!' or '!'),
			beautiful.red),
		message  = message,
		ontop    = true,
		timeout  = 0,
	})
end)

-- naughty config
naughty.config.defaults.position = "top_right"
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
