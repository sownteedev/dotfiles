local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local bluenetair = require(... .. ".mods.bluenetair")
local dndblurnight = require(... .. ".mods.dndblurnight")
local slider = require(... .. ".mods.slider")
local music = require(... .. ".mods.music")
local button = require(... .. ".mods.button")

return function(s)
	local control = wibox({
		screen = s,
		width = 500,
		height = 910,
		shape = beautiful.radius,
		bg = beautiful.background,
		ontop = true,
		visible = false,
	})

	control:setup({
		{
			{
				bluenetair,
				dndblurnight,
				spacing = 15,
				layout = wibox.layout.fixed.horizontal,
			},
			slider,
			music,
			button,
			spacing = 15,
			layout = wibox.layout.fixed.vertical,
		},
		margins = 15,
		widget = wibox.container.margin,
	})

	helpers.placeWidget(control, "top_right", 3, 0, 0, 10)
	helpers.slideAnimation("toggle::control", "close::control", "top", control, -control.height,
		beautiful.useless_gap * 6)

	return control
end
