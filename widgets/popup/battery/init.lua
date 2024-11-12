local beautiful = require("beautiful")
local wibox = require("wibox")

local charge = require(... .. ".epic")

local mouse_bat = charge("input-mouse-symbolic")
local keyboard_bat = charge("keyboards")
local headphone_bat = charge("headphones-symbolic")
local laptop_bat = charge("laptop-symbolic")

return function(s)
	local battery = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		ontop = false,
		visible = true,
	})

	battery:setup({
		{
			{
				{
					laptop_bat,
					mouse_bat,
					spacing = 40,
					layout = wibox.layout.fixed.horizontal,
				},
				{
					keyboard_bat,
					headphone_bat,
					spacing = 40,
					layout = wibox.layout.fixed.horizontal,
				},
				layout = wibox.layout.fixed.vertical,
				spacing = 20,
			},
			valign = "center",
			widget = wibox.container.place,
		},
		margins = 20,
		widget = wibox.container.margin,
	})
	_Utils.widget.placeWidget(battery, "top_left", 45, 0, 2, 0)
	_Utils.widget.popupOpacity(battery, 0.3)
	awesome.connect_signal("signal::blur", function(status)
		battery.bg = not status and beautiful.background or beautiful.background .. "88"
	end)

	return battery
end
