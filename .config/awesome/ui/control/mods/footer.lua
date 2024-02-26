local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")

local widget = wibox.widget({
	{
		{
			max_value = 100,
			value = 69,
			id = "prog",
			forced_height = 30,
			forced_width = 80,
			paddings = 3,
			border_color = beautiful.foreground .. "99",
			background_color = beautiful.background_alt,
			bar_shape = helpers.rrect(2),
			color = beautiful.blue,
			border_width = 1.25,
			shape = helpers.rrect(5),
			widget = wibox.widget.progressbar,
		},
		{
			{
				bg = beautiful.foreground .. "99",
				forced_height = 5,
				forced_width = 2,
				shape = helpers.rrect(10),
				widget = wibox.container.background,
			},
			widget = wibox.container.place,
			valign = "center",
		},
		spacing = 3,
		layout = wibox.layout.fixed.horizontal,
	},
	{
		font = beautiful.sans .. " 15",
		markup = helpers.colorizeText("25%", beautiful.foreground),
		valign = "center",
		id = "batvalue",
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal,
	spacing = 10,
})
awesome.connect_signal("signal::battery", function(value)
	local b = widget:get_children_by_id("prog")[1]
	local v = widget:get_children_by_id("batvalue")[1]
	v.markup = helpers.colorizeText(value .. "%", beautiful.foreground)
	b.value = value
	if value > 80 then
		b.color = beautiful.green
	elseif value > 20 then
		b.color = beautiful.blue
	else
		b.color = beautiful.red
	end
end)

return widget
