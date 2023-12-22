local wibox     = require("wibox")
local helpers   = require("helpers")
local beautiful = require("beautiful")
local awful     = require("awful")
local Launcher  = require("ui.launcher")

local profile   = wibox.widget {
	widget = wibox.widget.imagebox,
	image = beautiful.image,
	forced_height = 35,
	forced_width = 35,
	resize = true,
	buttons = {
		awful.button({}, 1, function()
			Launcher:open()
		end)
	},
}

return profile
