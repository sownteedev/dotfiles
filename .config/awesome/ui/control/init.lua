local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local buttons = require("ui.control.mods.buttons")
local music = require("ui.control.mods.music")
local sliders = require("ui.control.mods.slider")
local footer = require("ui.control.mods.footer")

awful.screen.connect_for_each_screen(function(s)
	local control = wibox({
		screen = s,
		width = beautiful.width / 4,
		height = (beautiful.height / 3) * 1.8,
		bg = beautiful.background .. "00",
		ontop = true,
		visible = false,
	})

	control:setup({
		{
			music,
			widget = wibox.container.margin,
			bottom = 20,
		},
		{
			{
				{
					footer,
					sliders,
					buttons,
					layout = wibox.layout.fixed.vertical,
					spacing = 35,
				},
				widget = wibox.container.margin,
				margins = 15,
			},
			widget = wibox.container.background,
			bg = beautiful.darker,
			shape = helpers.rrect(5),
		},
		nil,
		layout = wibox.layout.align.vertical,
	})

	awful.placement.bottom_right(control, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	awesome.connect_signal("toggle::control", function()
		control.visible = not control.visible
	end)
	awesome.connect_signal("close::control", function()
		control.visible = false
	end)
end)
