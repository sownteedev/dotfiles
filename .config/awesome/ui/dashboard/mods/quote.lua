local helpers = require("helpers")
local beautiful = require("beautiful")
local wibox = require("wibox")

local widget = wibox.widget {
	{
		{
			{
				{
					font = beautiful.sans .. " 12",
					markup = helpers.colorizeText("All our dreams can come true if we have the courage to pursue them", beautiful.foreground),
					widget = wibox.widget.textbox,
					valign = "start",
					align = "center"
				},
				{

					font = beautiful.sans .. " Bold 10",
					markup = helpers.colorizeText("Walt Disney", beautiful.violet),
					widget = wibox.widget.textbox,
					valign = "start",
					align = "center"
				},
				spacing = 20,
				layout = wibox.layout.fixed.vertical,
			},
			widget = wibox.container.margin,
			margins = 30
		},
		widget = wibox.container.background,
		bg = beautiful.background,
		shape = helpers.rrect(20),
	},
	widget = wibox.container.margin,
	top = 15
}

return widget
