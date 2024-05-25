local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")
local animation = require("modules.animation")

return function(s)
	local taglist = awful.widget.taglist({
		layout = {
			spacing = 10,
			layout = wibox.layout.fixed.horizontal,
		},
		style = { shape = helpers.rrect(5) },
		screen = s,
		filter = awful.widget.taglist.filter.all,
		buttons = {
			awful.button({}, 1, function(t)
				t:view_only()
			end),
		},
		widget_template = {
			{
				{
					{
						markup = '',
						shape  = helpers.rrect(0),
						id     = 'text_role',
						widget = wibox.widget.textbox,
					},
					widget = wibox.container.margin,
					left = 10,
					right = 10,
				},
				valign        = 'center',
				id            = 'background_role',
				shape         = helpers.rrect(0),
				widget        = wibox.container.background,
				forced_height = 30,
			},
			widget = wibox.container.place,
			valign = 'center',
		},
	})

	local tags = wibox.widget({
		{
			{
				{
					taglist,
					layout = wibox.layout.fixed.horizontal,
				},
				widget = wibox.container.margin,
				left = 20,
				right = 20,
			},
			widget = wibox.container.background,
			bg = beautiful.lighter,
			shape = helpers.rrect(5),
			shape_border_width = beautiful.border_width_custom,
			shape_border_color = beautiful.border_color,
		},
		widget = wibox.container.margin,
		top = 10,
		bottom = 10,
	})
	return tags
end
