local beautiful = require("beautiful")
local wibox = require("wibox")

local bluenetair = require(... .. ".mods.bluenetair")
local dndblurnight = require(... .. ".mods.dndblurnight")
local slider = require(... .. ".mods.slider")
local music = require(... .. ".mods.music")
local button = require(... .. ".mods.button")
local powerndark = require(... .. ".mods.powerndark")

return function(s)
	local control = wibox({
		screen = s,
		width = 500,
		height = 1015,
		shape = beautiful.radius,
		bg = beautiful.background,
		border_width = beautiful.border_width,
		border_color = beautiful.lighter,
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
			powerndark,
			slider,
			music,
			button,
			spacing = 15,
			layout = wibox.layout.fixed.vertical,
		},
		margins = 15,
		widget = wibox.container.margin,
	})

	_Utils.widget.placeWidget(control, "top_right", 3, 0, 0, 2)

	awesome.connect_signal("toggle::control", function()
		control.visible = not control.visible
	end)
	awesome.connect_signal("close::control", function()
		if control.visible then
			control.visible = false
		end
	end)

	awesome.connect_signal("signal::blur", function(status)
		control.bg = not status and beautiful.background or beautiful.background .. "DD"
	end)

	return control
end
