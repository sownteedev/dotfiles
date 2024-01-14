local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local widget = wibox.widget({
	{
		{
			{
				{
					id = "icon",
					image = gears.filesystem.get_configuration_dir() .. "theme/assets/weather/icons/weather-fog.svg",
					opacity = 0.9,
					clip_shape = helpers.rrect(4),
					forced_height = 80,
					forced_width = 80,
					valign = "center",
					widget = wibox.widget.imagebox,
				},
				{
					{
						id = "temp",
						font = beautiful.sans .. " 25",
						markup = "31 C",
						valign = "center",
						widget = wibox.widget.textbox,
					},
					{
						id = "desc",
						font = beautiful.sans .. " 10",
						markup = "Scattered Clouds",
						valign = "center",
						widget = wibox.widget.textbox,
					},
					spacing = 8,
					layout = wibox.layout.fixed.vertical,
				},
				spacing = 100,
				layout = wibox.layout.fixed.horizontal,
			},
			widget = wibox.container.place,
			valign = "center",
		},
		widget = wibox.container.margin,
		margins = 25,
	},
	widget = wibox.container.background,
	bg = beautiful.background,
	shape = helpers.rrect(5),
	forced_height = 195,
})

awesome.connect_signal("signal::weather", function(out)
	helpers.gc(widget, "icon").image = out.image
	helpers.gc(widget, "temp").markup = out.temp .. "°C"
	helpers.gc(widget, "desc").markup = out.desc
end)
return widget
