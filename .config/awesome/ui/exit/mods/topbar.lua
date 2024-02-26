local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")
local awful = require("awful")

local widget = wibox.widget({
	{
		{
			{
				widget = wibox.widget.imagebox,
				image = beautiful.profile,
				forced_height = 100,
				forced_width = 100,
				align = "center",
				valign = "center",
				clip_shape = helpers.rrect(40),
				resize = true,
			},
			{
				{
					widget = wibox.widget.textbox,
					markup = helpers.colorizeText("@" .. beautiful.user, beautiful.foreground),
					font = beautiful.sans .. " 20",
					align = "left",
					valign = "center",
				},
				widget = wibox.container.margin,
				left = 20,
			},
			{
				{
					{
						{
							font = beautiful.sans .. " 20",
							format = "%A, %d %B %Y",
							align = "center",
							valign = "center",
							widget = wibox.widget.textclock,
						},
						widget = wibox.container.margin,
						left = 25,
						right = 25,
					},
					shape = helpers.rrect(10),
					bg = beautiful.background_alt,
					widget = wibox.container.background,
				},
				{
					{
						{
							font = beautiful.sans .. " 20",
							id = "uptime",
							markup = helpers.colorizeText("", beautiful.foreground),
							valign = "center",
							widget = wibox.widget.textbox,
						},
						widget = wibox.container.margin,
						left = 25,
						right = 25,
					},
					shape = helpers.rrect(10),
					bg = beautiful.background_alt,
					widget = wibox.container.background,
				},
				{
					{
						{
							font = beautiful.icon .. " 25",
							markup = helpers.colorizeText("󰅖", beautiful.red),
							valign = "center",
							widget = wibox.widget.textbox,
						},
						widget = wibox.container.margin,
						margins = { left = 40, top = 20, right = 40, bottom = 20 },
					},
					buttons = {
						awful.button({}, 1, function()
							awesome.emit_signal("toggle::exit")
						end),
					},
					shape = helpers.rrect(10),
					bg = beautiful.background_alt,
					widget = wibox.container.background,
				},
				spacing = 40,
				layout = wibox.layout.fixed.horizontal,
			},
			layout = wibox.layout.align.horizontal,
		},
		widget = wibox.container.place,
		content_fill_horizontal = true,
		halign = "center",
		valign = "top",
	},
	widget = wibox.container.margin,
	top = 50,
	left = 50,
	right = 50,
})

awesome.connect_signal("signal::uptime", function(v)
	helpers.gc(widget, "uptime").markup = v
end)

return widget
