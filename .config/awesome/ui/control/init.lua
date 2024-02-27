local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local buttons = require("ui.control.mods.buttons")
local moosic = require("ui.control.mods.music")
local sliders = require("ui.control.mods.slider")
local footer = require("ui.control.mods.footer")

awful.screen.connect_for_each_screen(function(s)
	local control = wibox({
		screen = s,
		width = beautiful.width / 3.5,
		height = (beautiful.height / 3) * 2.07,
		bg = beautiful.background .. "00",
		ontop = true,
		visible = false,
	})

	control:setup({
		{
			{
				moosic,
				forced_height = 300,
				widget = wibox.container.background,
				bg = beautiful.background_dark,
				shape = helpers.rrect(5),
			},
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
					spacing = 60,
				},
				widget = wibox.container.margin,
				margins = 15,
			},
			widget = wibox.container.background,
			bg = beautiful.background_dark,
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
