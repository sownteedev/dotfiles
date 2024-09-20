local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

return function(s)
	local system = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		bg = beautiful.background,
		ontop = false,
		visible = true,
	})

	system:setup({
		{
			{
				{
					id = "disk",
					widget = wibox.container.arcchart,
					max_value = 100,
					min_value = 0,
					padding = 0,
					value = 50,
					rounded_edge = true,
					thickness = 25,
					start_angle = math.random(250, 870) * math.pi / 180,
					colors = { helpers.change_hex_lightness(beautiful.red, -10) },
					bg = helpers.change_hex_lightness(beautiful.red, 10),
					forced_width = 40,
					forced_height = 40,
				},
				id = "memory",
				widget = wibox.container.arcchart,
				max_value = 100,
				min_value = 0,
				value = 50,
				rounded_edge = true,
				thickness = 25,
				start_angle = math.random(250, 870) * math.pi / 180,
				colors = { helpers.change_hex_lightness(beautiful.blue, -10) },
				bg = helpers.change_hex_lightness(beautiful.blue, 10),
				forced_width = 130,
				forced_height = 130,
			},
			id = "cpu",
			widget = wibox.container.arcchart,
			max_value = 100,
			min_value = 0,
			value = 50,
			rounded_edge = true,
			thickness = 25,
			start_angle = math.random(250, 870) * math.pi / 180,
			colors = { helpers.change_hex_lightness(beautiful.green, -10) },
			bg = helpers.change_hex_lightness(beautiful.green, 10),
			forced_width = 150,
			forced_height = 150,
		},
		margins = 20,
		layout = wibox.container.margin,
	})

	awesome.connect_signal("signal::cpu", function(value)
		helpers.gc(system, "cpu").value = value
	end)
	awesome.connect_signal("signal::memory", function(value)
		helpers.gc(system, "memory").value = value
	end)
	awesome.connect_signal("signal::disk", function(value)
		helpers.gc(system, "disk").value = value
	end)
	helpers.placeWidget(system, "top_left", 103, 0, 33, 0)

	return system
end
