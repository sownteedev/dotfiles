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
				clip_shape = helpers.rrect(40),
				resize = true,
			},
			{
				{
					widget = wibox.widget.textbox,
					markup = helpers.colorizeText("@" .. beautiful.user, beautiful.foreground),
					font = beautiful.sans .. " 20",
					align = "left",
				},
				widget = wibox.container.margin,
				left = 20,
			},
			{
				{
					{
						{
							{
								font = beautiful.icon .. " 25",
								markup = helpers.colorizeText(" ", beautiful.yellow),
								widget = wibox.widget.textbox,
							},
							{
								font = beautiful.sans .. " 20",
								format = "%A, %d %B %Y",
								widget = wibox.widget.textclock,
							},
							layout = wibox.layout.fixed.horizontal,
							spacing = 10,
						},
						widget = wibox.container.margin,
						left = 25,
						right = 25,
					},
					widget = wibox.container.place,
				},
				{
					{
						{
							{
								font = beautiful.icon .. " 25",
								markup = helpers.colorizeText("󰾨 ", beautiful.green),
								widget = wibox.widget.textbox,
							},
							{
								font = beautiful.sans .. " 20",
								id = "uptime",
								markup = helpers.colorizeText("", beautiful.foreground),
								widget = wibox.widget.textbox,
							},
							layout = wibox.layout.fixed.horizontal,
							spacing = 10,
						},
						widget = wibox.container.margin,
						left = 25,
						right = 25,
					},
					widget = wibox.container.place,
				},
				{
					{
						{
							font = beautiful.icon .. " 25",
							markup = helpers.colorizeText("󰅖", beautiful.red),
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
					widget = wibox.container.place,
				},
				spacing = 40,
				layout = wibox.layout.fixed.horizontal,
			},
			layout = wibox.layout.align.horizontal,
		},
		widget = wibox.container.place,
		content_fill_horizontal = true,
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
