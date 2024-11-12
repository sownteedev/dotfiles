local beautiful = require("beautiful")
local wibox = require("wibox")
local gears = require("gears")
local animation = require("modules.animation")

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
		height = 1010,
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

	local slide = animation:new({
		duration = 0.5,
		pos = -control.height - 10,
		easing = animation.easing.inOutExpo,
		update = function(_, poss)
			control.y = poss
		end,
	})
	local slide_end = gears.timer({
		timeout = 0.5,
		single_shot = true,
		callback = function()
			control.visible = false
		end,
	})
	awesome.connect_signal("toggle::control", function()
		if control.visible then
			slide_end:start()
			slide:set(-control.height - 10)
		else
			control.visible = true
			slide:set(beautiful.useless_gap * 6)
		end
	end)
	awesome.connect_signal("close::control", function()
		if control.visible then
			slide_end:start()
			slide:set(-control.height - 10)
		end
	end)

	awesome.connect_signal("signal::blur", function(status)
		control.bg = not status and beautiful.background or beautiful.background .. "DD"
	end)

	return control
end
