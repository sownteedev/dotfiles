local awful       = require("awful")
local wibox       = require("wibox")
local beautiful   = require("beautiful")
local dpi         = require("beautiful").xresources.apply_dpi
local helpers     = require("helpers")
local hourminutes = wibox.widget {
	{
		{
			{
				{
					font = beautiful.sans .. " 10",
					format = "%I : %M",
					align = "center",
					valign = "center",
					widget = wibox.widget.textclock
				},
				widget = wibox.container.place,
				valign = "center"
			},
			{
				{
					font = beautiful.sans .. " 10",
					format = "%d %B",
					align = "center",
					valign = "center",
					widget = wibox.widget.textclock
				},
				widget = wibox.container.place,
				valign = "center"
			},
			layout = wibox.layout.fixed.horizontal,
			spacing = 10
		},
		margins = { left = dpi(10), right = dpi(10) },
		widget = wibox.container.margin
	},
	bg = beautiful.background_alt,
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal('toggle::moment')
		end)
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
}

return hourminutes
