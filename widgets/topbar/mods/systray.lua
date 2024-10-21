local wibox = require("wibox")

local systray = wibox.widget({
	{
		base_size = 25,
		widget = wibox.widget.systray,
	},
	widget = wibox.container.place,
	valign = "center",
})

return systray
