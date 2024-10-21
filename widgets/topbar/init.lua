local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local time = require(... .. ".mods.time")
local tags = require(... .. ".mods.tags")
local awmmenu = require(... .. ".mods.awmmenu")
local controlcenter = require(... .. ".mods.controlcenter")
local systray = require(... .. ".mods.systray")

return function(s)
	return awful.wibar {
		position = "top",
		height = 40,
		width = beautiful.width,
		bg = beautiful.background .. "33",
		ontop = false,
		screen = s,
		widget = {
			{
				{
					awmmenu,
					tags(s),
					spacing = 30,
					layout = wibox.layout.fixed.horizontal,
				},
				left = 30,
				widget = wibox.container.margin,
			},
			nil,
			{
				{
					systray,
					controlcenter,
					time,
					spacing = 30,
					layout = wibox.layout.fixed.horizontal,
				},
				right = 30,
				widget = wibox.container.margin,
			},
			layout = wibox.layout.align.horizontal,
		}
	}
end
