local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local notipower = wibox.widget({
	{
		{
			{
				{
					image = gears.filesystem.get_configuration_dir() .. "/themes/assets/notify/bell.png",
					resize = true,
					forced_height = 28,
					forced_width = 28,
					valign = "center",
					widget = wibox.widget.imagebox,
					buttons = {
						awful.button({}, 1, function()
							awesome.emit_signal("toggle::notify")
						end),
					},
				},
				{
					image = gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/power.png",
					resize = true,
					forced_height = 22,
					forced_width = 22,
					valign = "center",
					widget = wibox.widget.imagebox,
					buttons = {
						awful.button({}, 1, function()
							awesome.emit_signal("toggle::exit")
						end),
					},
				},
				spacing = 20,
				layout = wibox.layout.fixed.horizontal,
			},
			widget = wibox.container.margin,
			left = 20,
			right = 20,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(10),
		bg = beautiful.background,
	},
	widget = wibox.container.margin,
	top = 5,
	bottom = 5,
})

return notipower
