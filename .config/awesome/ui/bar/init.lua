local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local profile = require("ui.bar.mods.profile")
local tags = require("ui.bar.mods.tags")
local task = require("ui.bar.mods.task")
local bluewifibat = require("ui.bar.mods.bluewifibat")
local music = require("ui.bar.mods.music")
local timedate = require("ui.bar.mods.time")
local layout = require("ui.bar.mods.layout")
local systray = require("ui.bar.mods.systray")
local notipower = require("ui.bar.mods.notipower")

local function init(s)
	local wibar = awful.wibar({
		position = "bottom",
		margins = { bottom = beautiful.useless_gap * 2, left = 40, right = 40 },
		height = 70,
		ontop = false,
		width = beautiful.width - 100,
		bg = beautiful.darker,
		shape = helpers.rrect(5),
		screen = s,
		widget = {
			{
				{
					profile,
					layout,
					tags(s),
					task.widget,
					spacing = 15,
					layout = wibox.layout.fixed.horizontal,
				},
				widget = wibox.container.margin,
				left = 20,
			},
			nil,
			{
				{
					systray,
					music,
					bluewifibat,
					timedate,
					notipower,
					layout = wibox.layout.fixed.horizontal,
					spacing = 15,
				},
				widget = wibox.container.margin,
				right = 20,
			},
			layout = wibox.layout.align.horizontal,
		},
	})
	return wibar
end

screen.connect_signal("request::desktop_decoration", function(s)
	s.wibox = init(s)
end)
