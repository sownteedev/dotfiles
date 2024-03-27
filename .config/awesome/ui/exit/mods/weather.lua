local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")

local widget = wibox.widget({
	{
		id = "image",
		image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "themes/assets/weather/icons/weather-fog.svg",
			beautiful.foreground
		),
		opacity = 1,
		forced_height = 80,
		forced_width = 80,
		widget = wibox.widget.imagebox,
	},
	{
		id = "desc",
		font = beautiful.sans .. " 25",
		markup = "Scattered Clouds",
		align = "start",
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal,
	spacing = 20,
})

awesome.connect_signal("signal::weather", function(out)
	helpers.gc(widget, "desc").markup = out.desc
	helpers.gc(widget, "image").image = gears.color.recolor_image(out.image, beautiful.foreground)
end)

return widget
