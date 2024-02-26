local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")

local widget = wibox.widget({
	{
		id = "image",
		image = gears.filesystem.get_configuration_dir() .. "themes/assets/weather/icons/weather-fog.svg",
		opacity = 0.9,
		clip_shape = helpers.rrect(4),
		forced_height = 80,
		forced_width = 80,
		valign = "center",
		widget = wibox.widget.imagebox,
	},
	{
		id = "desc",
		font = beautiful.sans .. " 25",
		markup = "Scattered Clouds",
		valign = "center",
		align = "start",
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal,
	spacing = 20,
})

awesome.connect_signal("signal::weather", function(out)
	helpers.gc(widget, "desc").markup = out.desc
	helpers.gc(widget, "image").image = out.image
end)

return widget
