local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local widget = wibox.widget({
	{
		{
			{
				{
					font = beautiful.sans .. " SemiBold 30",
					format = helpers.colorizeText("%I : %M", beautiful.foreground),
					align = "center",
					valign = "center",
					widget = wibox.widget.textclock,
				},
				{
					font = beautiful.sans .. " 12",
					format = helpers.colorizeText("%A, %d %B", beautiful.foreground .. "99"),
					align = "center",
					valign = "center",
					widget = wibox.widget.textclock,
				},
				spacing = 8,
				layout = wibox.layout.fixed.vertical,
			},
			widget = wibox.container.place,
			halign = "center",
			valign = "center",
		},
		widget = wibox.container.margin,
		margin = 30,
	},
	shape = helpers.rrect(5),
	forced_height = 150,
	widget = wibox.container.background,
	bg = beautiful.background,
})

return widget
