local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local profile = require("ui.bar.mods.profile")
local tags = require("ui.bar.mods.tags")
local task = require("ui.bar.mods.task")
local battery = require("ui.bar.mods.battery")
local wifi = require("ui.bar.mods.wifi")
local bluetooth = require("ui.bar.mods.bluetooth")
local music = require("ui.bar.mods.music")
local timedate = require("ui.bar.mods.time")
local layout = require("ui.bar.mods.layout")
local systray = require("ui.bar.mods.systray")
local notipower = require("ui.bar.mods.notipower")

local function init(s)
	local wibar = awful.wibar({
		position = "bottom",
		height = 100,
		ontop = false,
		width = beautiful.width,
		bg = beautiful.background_dark,
		screen = s,
		widget = {
			{
				{
					{
						profile,
						layout,
						tags(s),
						task.widget,
						spacing = 15,
						layout = wibox.layout.fixed.horizontal,
					},
					widget = wibox.container.place,
					halign = "left",
				},
				widget = wibox.container.margin,
				left = 15,
			},
			{
				{
					{
						systray,
						music,
						{
							{
								{
									battery,
									wifi,
									bluetooth,
									spacing = 20,
									layout = wibox.layout.fixed.horizontal,
								},
								widget = wibox.container.margin,
								left = 15,
								right = 15,
							},
							widget = wibox.container.background,
							shape = helpers.rrect(5),
							bg = beautiful.background_alt,
							buttons = {
								awful.button({}, 1, function()
									awesome.emit_signal("toggle::control")
								end),
							},
						},
						timedate,
						notipower,
						layout = wibox.layout.fixed.horizontal,
						spacing = 15,
					},
					widget = wibox.container.place,
					halign = "right",
				},
				widget = wibox.container.margin,
				right = 15,
			},
			layout = wibox.layout.align.horizontal,
		},
	})
	return wibar
end

screen.connect_signal("request::desktop_decoration", function(s)
	s.wibox = init(s)
end)
