local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local widget = wibox.widget({
	{
		{
			widget = wibox.widget.imagebox,
			image = beautiful.profile,
			forced_height = 50,
			forced_width = 50,
			opacity = 1,
			resize = true,
		},
		{
			{
				{
					widget = wibox.widget.textbox,
					markup = helpers.colorizeText("Nguyen Thanh Son", beautiful.foreground),
					font = beautiful.sans .. " Medium 13",
				},
				{
					widget = wibox.widget.textbox,
					markup = helpers.colorizeText("@" .. beautiful.user, beautiful.foreground),
					font = "azuki_font 13",
				},
				layout = wibox.layout.fixed.vertical,
				spacing = 5,
			},
			widget = wibox.container.margin,
			top = 5,
		},
		layout = wibox.layout.fixed.horizontal,
		spacing = 20,
	},
	nil,
	{
		{
			{
				markup = "󰔎 ",
				font = beautiful.sans .. " 23",
				widget = wibox.widget.textbox,
			},
			widget = wibox.container.margin,
			left = 20,
			right = 10,
			top = 10,
			bottom = 10,
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

return widget
