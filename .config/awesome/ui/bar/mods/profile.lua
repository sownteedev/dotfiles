local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local Launcher = require("ui.launcher")

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
		halign = "center",
		valign = "center",
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return profile
