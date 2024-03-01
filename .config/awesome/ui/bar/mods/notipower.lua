local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local notipower = wibox.widget({
	{
		{
			{
				align = "center",
				font = beautiful.icon .. " 20",
				markup = helpers.colorizeText("󰂜 ", beautiful.accent),
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
			spacing = 10,
			layout = wibox.layout.fixed.horizontal,
		},
		widget = wibox.container.margin,
		left = 20,
		right = 10,
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
	bg = beautiful.background_alt,
})

return notipower
