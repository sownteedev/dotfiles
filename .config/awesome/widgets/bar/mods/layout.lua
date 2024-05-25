local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local layouts = awful.widget.layoutbox({
	buttons = {
		awful.button({
			modifiers = {},
			button = 1,
			on_press = function()
				awful.layout.inc(1)
			end,
		}),
		awful.button({
			modifiers = {},
			button = 3,
			on_press = function()
				awful.layout.inc(-1)
			end,
		}),
		awful.button({
			modifiers = {},
			button = 4,
			on_press = function()
				awful.layout.inc(-1)
			end,
		}),
		awful.button({
			modifiers = {},
			button = 5,
			on_press = function()
				awful.layout.inc(1)
			end,
		}),
	},
})

local widget = {
	{
		{
			layouts,
			margins = { top = 10, bottom = 10, left = 10, right = 10 },
			widget = wibox.container.margin,
		},
		bg = beautiful.lighter,
		forced_height = 0,
		shape = helpers.rrect(5),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		widget = wibox.container.background,
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
}

return widget