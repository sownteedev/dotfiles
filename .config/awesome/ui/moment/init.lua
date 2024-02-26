local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local calendar = require("ui.moment.mods.calendar")
local weather = require("ui.moment.mods.weather")
local clock = require("ui.moment.mods.clock")

awful.screen.connect_for_each_screen(function(s)
	local moment = wibox({
		shape = helpers.rrect(5),
		screen = s,
		width = beautiful.width / 3.5,
		height = beautiful.height / 1.2,
		bg = beautiful.background_dark,
		ontop = true,
		visible = false,
	})

	moment:setup({
		{
			clock,
			calendar(),
			weather,
			layout = wibox.layout.fixed.vertical,
			spacing = 15,
		},
		widget = wibox.container.margin,
		margins = 15,
	})
	awful.placement.bottom_right(moment, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	awesome.connect_signal("toggle::moment", function()
		moment.visible = not moment.visible
	end)
	awesome.connect_signal("close::moment", function()
		moment.visible = false
	end)
end)
