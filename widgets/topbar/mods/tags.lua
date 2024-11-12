local awful = require("awful")
local wibox = require("wibox")

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
			awful.button({}, 3, function()
				awesome.emit_signal("toggle::preview")
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

	_Utils.widget.hoverCursor(taglist)

	return taglist
end
