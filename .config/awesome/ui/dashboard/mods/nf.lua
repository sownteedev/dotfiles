local wibox     = require("wibox")
local beautiful = require("beautiful")
local helpers   = require("helpers")


local widget = wibox.widget {
	{
		{
			{
				{
					{
						{
							{
								font = beautiful.sans .. " 12",
								markup = helpers.colorizeText('󱄅 ', beautiful.background),
								widget = wibox.widget.textbox,
							},
							widget = wibox.container.margin,
							top = 5,
							bottom = 5,
							left = 10,
							right = 5,
						},
						widget = wibox.container.background,
						bg = beautiful.blue
					},
					{
						{
							font = beautiful.sans .. " 10",
							markup = helpers.colorizeText('tefetch', beautiful.green),
							widget = wibox.widget.textbox,
						},
						widget = wibox.container.place,
						valign = "center",
					},
					spacing = 15,
					layout = wibox.layout.fixed.horizontal,
				},
				nil,
				nil,
				layout = wibox.layout.align.horizontal,
			},
			{
				{
					widget = wibox.widget.imagebox,
					image = beautiful.fetch,
					forced_height = 100,
					forced_width = 100,
					resize = true,
				},
				{
					{
						font = beautiful.sans .. " 10",
						markup = helpers.colorizeText('OS:   Arch Linux', beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					{
						font = beautiful.sans .. " 10",
						markup = helpers.colorizeText('WM:   Awesome', beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					{
						font = beautiful.sans .. " 10",
						markup = helpers.colorizeText('USER:   ' .. beautiful.user, beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					{
						font = beautiful.sans .. " 10",
						markup = helpers.colorizeText('SHELL:   ZSH', beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					spacing = 8,
					layout = wibox.layout.fixed.vertical,
				},
				spacing = 40,
				layout = wibox.layout.fixed.horizontal,
			},
			{
				{
					{
						widget = wibox.container.background,
						bg = beautiful.accent,
						forced_height = 20,
						shape = helpers.rrect(5),
						forced_width = 20,
					},
					{
						widget = wibox.container.background,
						bg = beautiful.red,
						forced_height = 20,
						shape = helpers.rrect(5),
						forced_width = 20,
					},
					{
						widget = wibox.container.background,
						bg = beautiful.green,
						forced_height = 20,
						shape = helpers.rrect(5),
						forced_width = 20,
					},
					{
						widget = wibox.container.background,
						bg = beautiful.yellow,
						forced_height = 20,
						shape = helpers.rrect(5),
						forced_width = 20,
					},
					{
						widget = wibox.container.background,
						bg = beautiful.blue,
						forced_height = 20,
						shape = helpers.rrect(5),
						forced_width = 20,
					},
					{
						widget = wibox.container.background,
						bg = beautiful.violet,
						forced_height = 20,
						shape = helpers.rrect(5),
						forced_width = 20,
					},
					spacing = 15,
					layout = wibox.layout.fixed.horizontal,
				},
				widget = wibox.container.place,
				halign = "center"
			},
			spacing = 20,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 20
	},
	widget = wibox.container.background,
	bg = beautiful.background,
	shape = helpers.rrect(5)
}

return widget
