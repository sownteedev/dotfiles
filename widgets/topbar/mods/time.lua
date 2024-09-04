local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")

local timedate = wibox.widget({
	{
		font = beautiful.sans .. " Medium 12",
		format = "%A, %d %B %Y",
		align = "center",
		widget = wibox.widget.textclock,
	},
	{
		font = beautiful.sans .. " Medium 12",
		format = "%I : %M %p",
		align = "center",
		widget = wibox.widget.textclock,
	},
	layout = wibox.layout.fixed.horizontal,
	spacing = 20,
	buttons = gears.table.join(
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::noticenter")
		end)
	),
})

return timedate
