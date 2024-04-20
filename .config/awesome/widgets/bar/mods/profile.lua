local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local helpers = require("helpers")
local Launcher = require("widgets.launcher")

local profile = wibox.widget({
	{
		{
			{
				{
					widget = wibox.widget.imagebox,
					image = beautiful.profile,
					forced_height = 45,
					forced_width = 45,
					resize = true,
					buttons = {
						awful.button({}, 1, function()
							Launcher:toggle()
						end),
					},
				},
				widget = wibox.container.place,
			},
			widget = wibox.container.margin,
			top = 5,
			bottom = 5,
			left = 10,
			right = 5,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(5),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
	left = 15,
})

return profile
