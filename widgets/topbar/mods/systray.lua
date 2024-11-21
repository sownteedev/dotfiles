local wibox = require("wibox")

local systray = wibox.widget({
	{
		base_size = 25,
		widget = wibox.widget.systray,
	},
	valign = "center",
	widget = wibox.container.place,
})

return systray
