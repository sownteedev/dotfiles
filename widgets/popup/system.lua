local wibox = require("wibox")
local beautiful = require("beautiful")

return function(s)
	local system = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		ontop = false,
		visible = true,
	})

	system:setup({
		{
			{
				{
					{
						{
							id = "temp_gpu",
							widget = wibox.container.arcchart,
							max_value = 100,
							min_value = 0,
							padding = 0,
							value = 50,
							rounded_edge = true,
							thickness = 20,
							start_angle = math.random(250, 870) * math.pi / 180,
							colors = { _Utils.color.change_hex_lightness(_Utils.color.mix(beautiful.red, beautiful.blue, 0.5), -10) },
							bg = _Utils.color.change_hex_lightness(_Utils.color.mix(beautiful.red, beautiful.blue, 0.5),
								10),
						},
						id = "temp_cpu",
						widget = wibox.container.arcchart,
						max_value = 100,
						min_value = 0,
						padding = 0,
						value = 50,
						rounded_edge = true,
						thickness = 20,
						start_angle = math.random(250, 870) * math.pi / 180,
						colors = { _Utils.color.change_hex_lightness(beautiful.yellow, -10) },
						bg = _Utils.color.change_hex_lightness(beautiful.yellow, 10),
					},
					id = "disk",
					widget = wibox.container.arcchart,
					max_value = 100,
					min_value = 0,
					padding = 0,
					value = 50,
					rounded_edge = true,
					thickness = 20,
					start_angle = math.random(250, 870) * math.pi / 180,
					colors = { _Utils.color.change_hex_lightness(beautiful.red, -10) },
					bg = _Utils.color.change_hex_lightness(beautiful.red, 10),
				},
				id = "memory",
				widget = wibox.container.arcchart,
				max_value = 100,
				min_value = 0,
				value = 50,
				rounded_edge = true,
				thickness = 20,
				start_angle = math.random(250, 870) * math.pi / 180,
				colors = { _Utils.color.change_hex_lightness(beautiful.blue, -10) },
				bg = _Utils.color.change_hex_lightness(beautiful.blue, 10),
			},
			id = "cpu",
			widget = wibox.container.arcchart,
			max_value = 100,
			min_value = 0,
			value = 50,
			rounded_edge = true,
			thickness = 20,
			start_angle = math.random(250, 870) * math.pi / 180,
			colors = { _Utils.color.change_hex_lightness(beautiful.green, -10) },
			bg = _Utils.color.change_hex_lightness(beautiful.green, 10),
		},
		margins = 15,
		layout = wibox.container.margin,
	})

	awesome.connect_signal("signal::cpu", function(value)
		_Utils.widget.gc(system, "cpu").value = value
	end)
	awesome.connect_signal("signal::memory", function(value)
		_Utils.widget.gc(system, "memory").value = value
	end)
	awesome.connect_signal("signal::disk", function(value)
		_Utils.widget.gc(system, "disk").value = value
	end)
	awesome.connect_signal("signal::temp_cpu", function(value)
		_Utils.widget.gc(system, "temp_cpu").value = value
	end)
	awesome.connect_signal("signal::temp_gpu", function(value)
		_Utils.widget.gc(system, "temp_gpu").value = value
	end)

	_Utils.widget.placeWidget(system, "top_left", 103, 0, 33, 0)
	_Utils.widget.popupOpacity(system, 0.3)
	awesome.connect_signal("signal::blur", function(status)
		system.bg = not status and beautiful.background or beautiful.background .. "AA"
	end)

	return system
end
