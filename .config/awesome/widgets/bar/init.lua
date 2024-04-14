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

local function init(s)
	local wibar = awful.wibar({
		position = "bottom",
		margins = { bottom = beautiful.useless_gap * 2 },
		height = 70,
		ontop = false,
		width = beautiful.width - 150,
		bg = beautiful.darker,
		shape = helpers.rrect(10),
		screen = s,
		widget = {
			{
				profile,
				layout,
				tags(s),
				task.widget,
				spacing = 15,
				layout = wibox.layout.fixed.horizontal,
			},
			nil,
			{
				systray,
				music,
				bluewifibat,
				timedate,
				notipower,
				layout = wibox.layout.fixed.horizontal,
				spacing = 15,
			},
			layout = wibox.layout.align.horizontal,
		},
	})
	return wibar
end

screen.connect_signal("request::desktop_decoration", function(s)
	s.wibox = init(s)
end)
