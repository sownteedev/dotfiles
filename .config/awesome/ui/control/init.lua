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
		width = 400,
		height = 650,
		bg = beautiful.background .. "00",
		ontop = true,
		visible = false,
	})

	control:setup {
		{
			{
				moosic,
				forced_height = 210,
				widget = wibox.container.background,
				bg = beautiful.background_dark,
				shape = helpers.rrect(10),
			},
			widget = wibox.container.margin,
			bottom = 10,
		},
		{
			{
				{
					{

						{
							layout = wibox.layout.align.horizontal,
							{
								{
									widget = wibox.widget.imagebox,
									image = beautiful.profile,
									forced_height = 40,
									forced_width = 40,
									opacity = 1,
									clip_shape = helpers.rrect(8),
									resize = true,
								},
								{
									{
										{
											footer,
											widget = wibox.container.place,
											valign = "center",
										},
										widget = wibox.container.margin,
										left = 10,
										right = 10,
									},
									widget = wibox.container.background,
									shape = helpers.rrect(5),
									bg = beautiful.background_alt,
								},
								layout = wibox.layout.fixed.horizontal,
								spacing = 20,
							},
							-- {
							-- {
							-- 	{
							-- 		font = beautiful.icon_font .. " 12",
							-- 		markup = helpers.colorizeText("󰐱", beautiful.foreground),
							-- 		widget = wibox.widget.textbox,
							-- 		valign = "center",
							-- 		align = "center"
							-- 	},
							-- 	widget = wibox.container.margin,
							-- 	margins = 10
							-- },
							-- widget = wibox.container.background,
							-- shape = helpers.rrect(6),
							-- buttons = {
							-- 	awful.button({}, 1, function()
							-- 		awesome.emit_signal('toggle::setup')
							-- 	end)
							-- },
							-- bg = beautiful.background_alt,
							-- },
						},
						widget = wibox.container.margin,
					},
					sliders,
					buttons,
					layout = wibox.layout.fixed.vertical,
					spacing = 25,
				},
				widget = wibox.container.margin,
				left = 20,
				right = 20,
				top = 20,
			},
			widget = wibox.container.background,
			bg = beautiful.background_dark,
			shape = helpers.rrect(10),
		},
		nil,
		layout = wibox.layout.align.vertical,
	}
	awful.placement.bottom_right(control, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	awesome.connect_signal("toggle::control", function()
		control.visible = not control.visible
	end)
end)
