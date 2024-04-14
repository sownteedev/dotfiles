local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local Launcher = require("widgets.launcher")

local profile = wibox.widget({
	{
		{
			widget = wibox.widget.imagebox,
			image = beautiful.profile,
			forced_height = 50,
			forced_width = 50,
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
	left = 15,
})

return profile
