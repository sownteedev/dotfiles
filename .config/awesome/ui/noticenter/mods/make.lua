local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")

return function(icon, n)
	local time = os.date("%H:%M:%S")

	local icon_widget = wibox.widget({
		widget = wibox.container.constraint,
		{
			widget = wibox.widget.imagebox,
			image = helpers.cropSurface(1, gears.surface.load_uncached(icon)),
			resize = true,
			clip_shape = gears.shape.circle,
			halign = "center",
			valign = "center",
		},
	})

	local title_widget = wibox.widget({
		widget = wibox.container.scroll.horizontal,
		step_function = wibox.container.scroll.step_functions.waiting_nonlinear_back_and_forth,
		speed = 80,
		forced_width = 200,
		{
			widget = wibox.widget.textbox,
			text = n.title,
			align = "left",
			font = beautiful.sans .. " 20",
			forced_width = 300,
		},
	})

	local time_widget = wibox.widget({
		widget = wibox.widget.textbox,
		text = time,
		align = "right",
	})

	local text_notif = wibox.widget({
		markup = n.message,
		align = "left",
		forced_width = 165,
		font = beautiful.sans .. " 15",
		widget = wibox.widget.textbox,
	})

	local box = wibox.widget({
		widget = wibox.container.background,
		forced_height = 150,
		shape = helpers.rrect(5),
		bg = beautiful.background,
		{
			{
				layout = wibox.layout.align.horizontal,
				icon_widget,
				{
					widget = wibox.container.margin,
					left = 40,
					{
						layout = wibox.layout.align.vertical,
						{
							layout = wibox.layout.fixed.vertical,
							expand = "none",
							spacing = 40,
							{
								layout = wibox.layout.align.horizontal,
								title_widget,
								nil,
								time_widget,
							},
							text_notif,
						},
					},
				},
			},
			widget = wibox.container.margin,
			left = 20,
			right = 20,
			top = 20,
			bottom = 20,
		},
	})

	box:buttons(gears.table.join(awful.button({}, 1, function()
		_G.notif_center_remove_notif(box)
	end)))

	return box
end
