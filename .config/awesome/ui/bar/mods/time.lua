local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local time = wibox.widget({
	{
		{
			{
				{
					font = beautiful.sans .. " 15",
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
					font = beautiful.sans .. " 15",
					format = "%A, %d %B %Y",
					align = "center",
					valign = "center",
					widget = wibox.widget.textclock,
				},
				widget = wibox.container.place,
				valign = "center",
			},
			layout = wibox.layout.fixed.horizontal,
			spacing = 20,
		},
		margins = { left = 20, right = 20 },
		widget = wibox.container.margin,
	},
	bg = beautiful.background_alt,
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::moment")
		end),
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
})

return time
