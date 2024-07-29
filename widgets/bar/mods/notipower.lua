local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")
local exit = require("widgets.exit")

local notipower = wibox.widget({
	{
		{
			{
				image = gears.filesystem.get_configuration_dir() .. "/themes/assets/notify/bell.png",
				resize = true,
				forced_height = 23,
				forced_width = 23,
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
				forced_height = 17,
				forced_width = 17,
				valign = "center",
				widget = wibox.widget.imagebox,
				buttons = {
					awful.button({}, 1, function()
						exit:toggle()
					end),
				},
			},
			spacing = 15,
			layout = wibox.layout.fixed.horizontal,
		},
		widget = wibox.container.margin,
		left = 15,
		right = 15,
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
	bg = beautiful.lighter,
	shape_border_width = beautiful.border_width_custom,
	shape_border_color = beautiful.border_color,
})

return notipower
