local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local buttons = require("ui.control.mods.buttons")
local moosic = require("ui.control.mods.music")
local sliders = require("ui.control.mods.slider")
local footer = require("ui.control.mods.footer")

local opacity = false

awful.screen.connect_for_each_screen(function(s)
	local control = wibox({
		screen = s,
		width = beautiful.width / 3.5,
		height = (beautiful.height / 3) * 2.05,
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
					{

						{
							layout = wibox.layout.align.horizontal,
							{
								{
									widget = wibox.widget.imagebox,
									image = beautiful.profile,
									forced_height = 80,
									forced_width = 80,
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
								spacing = 40,
							},
							nil,
							{
								{
									{
										font = beautiful.icon .. " 25",
										markup = helpers.colorizeText("󱡓 ", beautiful.foreground),
										widget = wibox.widget.textbox,
										valign = "center",
										align = "center",
									},
									widget = wibox.container.margin,
									left = 30,
									right = 20,
									top = 10,
									bottom = 10,
								},
								widget = wibox.container.background,
								shape = helpers.rrect(5),
								buttons = {
									awful.button({}, 1, function()
										opacity = not opacity
										if opacity then
											awful.spawn.with_shell(
												"~/.config/awesome/signals/scripts/Picom/toggle --opacity &"
											)
										else
											awful.spawn.with_shell(
												"~/.config/awesome/signals/scripts/Picom/toggle --no-opacity &"
											)
										end
									end),
								},
								bg = beautiful.background_alt,
							},
						},
						widget = wibox.container.margin,
					},
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
