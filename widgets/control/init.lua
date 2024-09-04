local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")
local gears = require("gears")
local animation = require("modules.animation")

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
	local slide = animation:new({
		duration = 1,
		pos = -control.height,
		easing = animation.easing.inOutExpo,
		update = function(_, pos)
			control.y = pos
		end,
	})
	local slide_end = gears.timer({
		timeout = 1,
		single_shot = true,
		callback = function()
			control.visible = false
		end,
	})
	awesome.connect_signal("toggle::control", function()
		if control.visible then
			slide_end:start()
			slide:set(-control.height)
		else
			control.visible = true
			slide:set(beautiful.useless_gap * 6)
		end
	end)
	awesome.connect_signal("close::control", function()
		slide_end:start()
		slide:set(-control.height)
	end)

	return control
end
