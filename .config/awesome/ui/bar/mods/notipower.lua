local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local notipower = wibox.widget({
	{
		{
			{
				{
					font = beautiful.icon .. " 20",
					markup = helpers.colorizeText("󰂜 ", beautiful.green),
					widget = wibox.widget.textbox,
					buttons = {
						awful.button({}, 1, function()
							awesome.emit_signal("toggle::notify")
						end),
					},
				},
				{
					font = beautiful.icon .. " 20",
					markup = helpers.colorizeText("󰐥 ", beautiful.red),
					widget = wibox.widget.textbox,
					buttons = {
						awful.button({}, 1, function()
							awesome.emit_signal("toggle::exit")
						end),
					},
				},
				spacing = 15,
				layout = wibox.layout.fixed.horizontal,
			},
			widget = wibox.container.margin,
			left = 20,
			right = 10,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(5),
		bg = beautiful.background,
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return notipower
