local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local time = require(... .. ".mods.time")
local tags = require(... .. ".mods.tags")
local awmmenu = require(... .. ".mods.awmmenu")
local controlcenter = require(... .. ".mods.controlcenter")

return function(s)
	return awful.wibar {
		position = "top",
		height = 40,
		width = beautiful.width,
		bg = helpers.blend("#ffffff", "#000000", 0.3) .. "33",
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
