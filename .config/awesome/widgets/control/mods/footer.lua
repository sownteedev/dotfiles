local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local widget = wibox.widget({
	{
		{
			widget = wibox.widget.imagebox,
			image = beautiful.profile,
			forced_height = 70,
			forced_width = 70,
			opacity = 1,
			resize = true,
		},
		{
			{
				{
					widget = wibox.widget.textbox,
					markup = helpers.colorizeText("Nguyen Thanh Son", beautiful.foreground),
					font = beautiful.sans .. " Medium 15",
				},
				{
					widget = wibox.widget.textbox,
					markup = helpers.colorizeText("@" .. beautiful.user, beautiful.foreground),
					font = "azuki_font 15",
				},
				layout = wibox.layout.fixed.vertical,
				spacing = 5,
			},
			widget = wibox.container.margin,
			top = 10,
		},
		layout = wibox.layout.fixed.horizontal,
		spacing = 20,
	},
	nil,
	{
		{
			{
				id = "icon",
				widget = wibox.widget.textbox,
				markup = "󰔎 ",
				font = beautiful.sans .. " 25",
			},
			widget = wibox.container.margin,
			left = 25,
			right = 10,
			top = 15,
			bottom = 15,
		},
		id = "back",
		widget = wibox.container.background,
		shape = helpers.rrect(10),
		bg = beautiful.lighter,
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.easy_async_with_shell("awesome-client 'darkmode()' &")
			end),
		},
	},
	layout = wibox.layout.align.horizontal,
})

helpers.addHover(widget, "back", beautiful.background, beautiful.lighter)

return widget
