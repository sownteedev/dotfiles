local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")

return function(s)
	local taglist = awful.widget.taglist({
		layout = {
			spacing = 30,
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
				id     = 'text_role',
				widget = wibox.widget.textbox,
			},
			widget = wibox.container.place,
			valign = 'center',
		},
	})

	helpers.hoverCursor(taglist)

	return taglist
end
