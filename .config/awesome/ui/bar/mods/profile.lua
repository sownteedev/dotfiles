local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local Launcher = require("ui.launcher")
local dpi = beautiful.xresources.apply_dpi

local profile = wibox.widget({
	widget = wibox.widget.imagebox,
	image = beautiful.profile,
	forced_height = dpi(60),
	forced_width = dpi(60),
	resize = true,
	buttons = {
		awful.button({}, 1, function()
			Launcher:toggle()
		end),
	},
})

return profile
