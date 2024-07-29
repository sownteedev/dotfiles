local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local profile = require(... .. ".mods.profile")
local tags = require(... .. ".mods.tags")
local task = require(... .. ".mods.task")
local bluewifibat = require(... .. ".mods.bluewifibat")
local music = require(... .. ".mods.music")
local timedate = require(... .. ".mods.time")
local layout = require(... .. ".mods.layout")
local systray = require(... .. ".mods.systray")
local notipower = require(... .. ".mods.notipower")
require(... .. ".mods.preview")

awful.screen.connect_for_each_screen(function(s)
	s.wibar = awful.wibar {
		position = "bottom",
		margins = { bottom = beautiful.useless_gap * 2 },
		shape = helpers.rrect(10),
		height = 70,
		width = beautiful.width - 100,
		bg = beautiful.background,
		ontop = false,
		screen = s,
		widget = {
			{
				{
					profile,
					tags(s),
					spacing = 10,
					layout = wibox.layout.fixed.horizontal,
				},
				margins = 10,
				widget = wibox.container.margin,
			},
			task.widget,
			{
				{
					systray,
					music,
					bluewifibat,
					timedate,
					layout,
					notipower,
					layout = wibox.layout.fixed.horizontal,
					spacing = 10,
				},
				margins = 10,
				widget = wibox.container.margin,
			},
			layout = wibox.layout.align.horizontal,
		},
	}
end)
