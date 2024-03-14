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
						{
							font = beautiful.sans .. " Bold 14",
							format = "%I : %M %p",
							align = "center",
							valign = "center",
							widget = wibox.widget.textclock,
						},
						widget = wibox.container.place,
						valign = "center",
					},
					{
						{
							font = beautiful.sans .. " 12",
							format = "%A, %d %B %Y",
							align = "center",
							valign = "center",
							widget = wibox.widget.textclock,
						},
						widget = wibox.container.place,
						valign = "center",
					},
					layout = wibox.layout.fixed.vertical,
					spacing = 5,
				},
				widget = wibox.container.place,
				halign = "center",
			},
			widget = wibox.container.margin,
			right = 20,
			left = 20,
		},
		bg = beautiful.lighter,
		buttons = {
			awful.button({}, 1, function()
				awesome.emit_signal("toggle::moment")
			end),
		},
		widget = wibox.container.background,
		shape = helpers.rrect(5),
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return timedate
