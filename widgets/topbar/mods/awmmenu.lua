local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")

local awmmenu = wibox.widget({
	widget = wibox.widget.imagebox,
	image = gears.color.recolor_image(beautiful.icon_path .. "awm/awm.png", beautiful.foreground),
	forced_height = 20,
	forced_width = 20,
	resize = true,
	valign = "center",
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::exit")
		end),
	},
})
_Utils.widget.hoverCursor(awmmenu)

return awmmenu
