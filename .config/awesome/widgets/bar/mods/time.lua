local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local timedate = wibox.widget({
	{
		{
			{
				{
					{
						font = beautiful.sans .. " Bold 13",
						format = "%I : %M %p",
						align = "center",
						widget = wibox.widget.textclock,
					},
					{
						font = beautiful.sans .. " 11",
						format = "%A, %d %B %Y",
						align = "center",
						widget = wibox.widget.textclock,
					},
					layout = wibox.layout.fixed.vertical,
					spacing = 3,
				},
				widget = wibox.container.place,
			},
			widget = wibox.container.margin,
			right = 20,
			left = 20,
		},
		bg = beautiful.lighter,
		widget = wibox.container.background,
		shape = helpers.rrect(5),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		buttons = {
			awful.button({}, 1, function()
				awesome.emit_signal("toggle::moment")
			end),
		},
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return timedate