local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")

return function(icon, n)
	local action_widget = {
		{
			{
				id = "text_role",
				align = "center",
				font = beautiful.sans .. " 12",
				widget = wibox.widget.textbox,
			},
			bg = beautiful.lighter1,
			shape = helpers.rrect(10),
			forced_height = 30,
			widget = wibox.container.background,
		},
		widget = wibox.container.margin,
		left = 20,
		right = 20,
	}
	local actions = wibox.widget({
		notification = n,
		base_layout = wibox.widget({
			spacing = 30,
			layout = wibox.layout.flex.horizontal,
		}),
		align = "center",
		widget_template = action_widget,
		style = { underline_normal = false, underline_selected = true },
		widget = naughty.list.actions,
	})

	local icon_widget = wibox.widget({
		widget = wibox.container.constraint,
		{
			widget = wibox.widget.imagebox,
			image = helpers.cropSurface(1, gears.surface.load_uncached(icon)),
			resize = true,
			clip_shape = gears.shape.circle,
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
		text = os.date("%H:%M"),
		align = "right",
		font = beautiful.sans .. " 12",
	})

	local text_notif = wibox.widget({
		markup = n.message,
		align = "left",
		forced_width = 165,
		font = beautiful.sans .. " 13",
		widget = wibox.widget.textbox,
	})

	local box = wibox.widget({
		widget = wibox.container.background,
		forced_height = 180,
		shape = helpers.rrect(10),
		bg = beautiful.lighter,
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		{
			{
				layout = wibox.layout.align.horizontal,
				icon_widget,
				{
					widget = wibox.container.margin,
					left = 40,
					{
						{
							layout = wibox.layout.align.horizontal,
							title_widget,
							nil,
							time_widget,
						},
						text_notif,
						actions,
						layout = wibox.layout.fixed.vertical,
						spacing = 30,
					},
				},
			},
			widget = wibox.container.margin,
			margins = 15,
		},
	})

	box:buttons(gears.table.join(awful.button({}, 1, function()
		_G.notif_center_remove_notif(box)
	end)))

	return box
end
