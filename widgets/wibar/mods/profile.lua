local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local helpers = require("helpers")
local gears = require("gears")

local profile = wibox.widget({
	{
		{
			widget = wibox.widget.imagebox,
			image = gears.filesystem.get_configuration_dir() .. "/themes/assets/cat.jpg",
			forced_height = 40,
			forced_width = 40,
			resize = true,
			clip_shape = helpers.rrect(100),
			buttons = {
				awful.button({}, 1, function()
					awesome.emit_signal("toggle::launcher")
				end),
			},
		},
		margins = 5,
		widget = wibox.container.margin,
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
	shape_border_width = beautiful.border_width_custom,
	shape_border_color = beautiful.border_color,
})

return profile
