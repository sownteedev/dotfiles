local wibox = require("wibox")
local gears = require("gears")

return wibox.widget({
	{
		{
			image = gears.filesystem.get_configuration_dir() .. "/themes/assets/notify/wedding-bells.png",
			resize = true,
			forced_height = 400,
			halign = "center",
			widget = wibox.widget.imagebox,
		},
		widget = wibox.container.place,
		valign = "center",
	},
	widget = wibox.container.background,
	forced_height = 800,
})