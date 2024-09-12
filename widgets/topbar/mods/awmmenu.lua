local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local awmmenu = wibox.widget({
	{
		widget = wibox.widget.imagebox,
		image = gears.color.recolor_image(beautiful.icon_path .. "awm/awm.png", beautiful.foreground),
		forced_height = 20,
		forced_width = 20,
		resize = true,
		buttons = {},
	},
	align = "center",
	widget = wibox.container.place,
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::exit")
		end),
	},
})
helpers.hoverCursor(awmmenu)

return awmmenu
