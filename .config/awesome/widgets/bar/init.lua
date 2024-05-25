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

local pos = "float"
local a = nil
local b = nil
if pos == "float" then
	a = beautiful.useless_gap * 2
	b = 100
elseif pos == "bottom" then
	a = 0
	b = 0
end

local function init(s)
	local wibar = awful.wibar({
		position = "bottom",
		margins = { bottom = a },
		shape = helpers.rrect(5),
		height = 70,
		ontop = false,
		width = beautiful.width - b,
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
			widget = wibox.container.background,
			bg = beautiful.background,
			shape = helpers.rrect(5),
			shape_border_width = beautiful.border_width_custom,
			shape_border_color = beautiful.border_color,
		},
	})
	return wibar
end

screen.connect_signal("request::desktop_decoration", function(s)
	s.wibox = init(s)
end)
