local awful = require("awful")
local wibox = require("wibox")

return function(s)
	local taglist = awful.widget.taglist({
		layout = {
			spacing = 10,
			layout = wibox.layout.fixed.horizontal,
		},
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
					markup = '',
					id     = 'text_role',
					widget = wibox.widget.textbox,
				},
				widget = wibox.container.margin,
				left = 10,
				right = 10,
			},
			widget = wibox.container.place,
			valign = 'center',
		},
	})

	local tags = wibox.widget({
		taglist,
		layout = wibox.layout.fixed.horizontal,
	})
	return tags
end
