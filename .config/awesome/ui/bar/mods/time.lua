local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = require("beautiful").xresources.apply_dpi
local helpers = require("helpers")
local time = wibox.widget({
	{
		{
			{
				{
					font = beautiful.sans .. " 15",
					format = "%I : %M",
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
					format = "%a, %d %B",
					align = "center",
					valign = "center",
					widget = wibox.widget.textclock,
				},
				widget = wibox.container.place,
				valign = "center",
			},
			layout = wibox.layout.fixed.horizontal,
			spacing = dpi(20),
		},
		margins = { left = dpi(20), right = dpi(20) },
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
