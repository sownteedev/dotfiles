local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")
local gears = require("gears")

return wibox.widget {
	{
		{
			{
				widget = wibox.widget.textbox,
				markup = helpers.colorizeText("No Notifications", beautiful.foreground),
				font = beautiful.sans .. " 12",
				valign = "center",
				align = "center"
			},
			{
				image = gears.filesystem.get_configuration_dir() .. "/themes/assets/wedding-bells.png",
				resize = true,
				forced_height = 250,
				halign = "center",
				valign = "center",
				widget = wibox.widget.imagebox,
			},
			spacing = 20,
			layout = wibox.layout.fixed.vertical
		},
		widget = wibox.container.place,
		valign = 'center'
	},
	widget = wibox.container.background,
	forced_height = 400,
}
