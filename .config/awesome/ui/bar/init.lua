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
local hourminutes = require("ui.bar.mods.time")
local layout = require("ui.bar.mods.layout")
local systray = require("ui.bar.mods.systray")

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
						{
							{
								tags(s),
								widget = wibox.container.margin,
								left = 20,
								right = 20,
							},
							shape = helpers.rrect(5),
							widget = wibox.container.background,
							bg = beautiful.background_alt,
						},
						task.widget,
						spacing = 20,
						layout = wibox.layout.fixed.horizontal,
					},
					widget = wibox.container.place,
					halign = "left",
				},
				widget = wibox.container.margin,
				left = 20,
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
									spacing = 25,
									layout = wibox.layout.fixed.horizontal,
								},
								widget = wibox.container.margin,
								left = 20,
								right = 20,
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
						hourminutes,
						{
							{
								{
									{
										align = "center",
										font = beautiful.icon .. " 20",
										markup = helpers.colorizeText("󰂜 ", beautiful.foreground),
										widget = wibox.widget.textbox,
										buttons = {
											awful.button({}, 1, function()
												awesome.emit_signal("toggle::notify")
											end),
										},
									},
									{
										align = "center",
										font = beautiful.icon .. " 20",
										markup = helpers.colorizeText("󰐥 ", beautiful.red),
										widget = wibox.widget.textbox,
										buttons = {
											awful.button({}, 1, function()
												awesome.emit_signal("toggle::exit")
											end),
										},
									},
									spacing = 20,
									layout = wibox.layout.fixed.horizontal,
								},
								widget = wibox.container.margin,
								left = 20,
								right = 10,
							},
							widget = wibox.container.background,
							shape = helpers.rrect(5),
							bg = beautiful.background_alt,
						},
						layout = wibox.layout.fixed.horizontal,
						spacing = 20,
					},
					widget = wibox.container.place,
					valign = "center",
					halign = "right",
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
