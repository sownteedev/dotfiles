local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local dpi = beautiful.xresources.apply_dpi

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
			id = "icon",
			clip_shape = helpers.rrect(3),
			widget = wibox.container.margin,
		},
		margins = dpi(15),
		widget = wibox.container.margin,
	},
	bg = beautiful.background_alt,
	forced_height = dpi(40),
	shape = helpers.rrect(5),
	widget = wibox.container.background,
}
return widget
