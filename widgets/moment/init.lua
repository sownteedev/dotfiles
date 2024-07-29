local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local calendar = require(... .. ".mods.calendar")
local weather = require(... .. ".mods.weather")
local clock = require(... .. ".mods.clock")

awful.screen.connect_for_each_screen(function(s)
	local moment = wibox({
		screen = s,
		width = beautiful.width / 4,
		height = beautiful.height / 1.27,
		ontop = true,
		visible = false,
	})

	moment:setup({
		{
			{
				clock,
				calendar(),
				weather,
				layout = wibox.layout.fixed.vertical,
				spacing = 15,
			},
			widget = wibox.container.margin,
			margins = 15,
		},
		widget = wibox.container.background,
		bg = beautiful.background,
		shape = helpers.rrect(5),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
	})
	helpers.placeWidget(moment, "bottom_right", 0, 2, 0, 2)
	awesome.connect_signal("toggle::moment", function()
		moment.visible = not moment.visible
	end)
	awesome.connect_signal("close::moment", function()
		moment.visible = false
	end)
end)
