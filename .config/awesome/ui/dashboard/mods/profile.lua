local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local widget = wibox.widget({
	{
		{
			{
				{
					{
						widget = wibox.widget.imagebox,
						image = beautiful.profile,
						forced_height = 80,
						forced_width = 80,
						clip_shape = helpers.rrect(100),
						resize = true,
					},
					widget = wibox.container.place,
					halign = "center",
				},
				{
					markup = helpers.colorizeText("Welcome, " .. beautiful.user .. "!", beautiful.foreground),
					align = "center",
					font = beautiful.sans .. " 13",
					widget = wibox.widget.textbox,
				},
				{
					id = "uptime",
					markup = helpers.colorizeText("Running since ", beautiful.foreground),
					align = "center",
					font = beautiful.sans .. " 10",
					widget = wibox.widget.textbox,
				},
				spacing = 10,
				layout = wibox.layout.fixed.vertical,
			},
			widget = wibox.container.margin,
			margins = 30,
		},
		shape = helpers.rrect(5),
		widget = wibox.container.background,
		bg = beautiful.background,
	},
	widget = wibox.container.margin,
	bottom = 15,
})
awesome.connect_signal("signal::uptime", function(v)
	helpers.gc(widget, "uptime").markup = helpers.colorizeText(v, beautiful.foreground .. "99")
end)

return widget
