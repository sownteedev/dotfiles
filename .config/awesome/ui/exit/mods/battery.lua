local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")
local widget = wibox.widget({
	{
		{
			max_value = 100,
			value = 69,
			id = "prog",
			forced_height = 0,
			forced_width = 200,
			paddings = 5,
			border_color = beautiful.foreground .. "99",
			background_color = beautiful.lighter,
			bar_shape = helpers.rrect(15),
			color = beautiful.blue,
			border_width = 1.25,
			shape = helpers.rrect(15),
			widget = wibox.widget.progressbar,
		},
		{
			{
				bg = beautiful.foreground .. "99",
				forced_height = 20,
				forced_width = 3,
				shape = helpers.rrect(10),
				widget = wibox.container.background,
			},
			widget = wibox.container.place,
		},
		spacing = 5,
		layout = wibox.layout.fixed.horizontal,
	},
	{
		font = beautiful.sans .. " 25",
		markup = helpers.colorizeText("25%", beautiful.foreground),
		id = "batvalue",
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal,
	spacing = 20,
})

awesome.connect_signal("signal::battery", function(value)
	local b = widget:get_children_by_id("prog")[1]
	local v = widget:get_children_by_id("batvalue")[1]
	v.markup = helpers.colorizeText(value .. "%", beautiful.foreground)
	b.value = value
	if value >= 75 then
		b.color = beautiful.green
	elseif value >= 50 then
		b.color = beautiful.blue
	elseif value >= 25 then
		b.color = beautiful.yellow
	else
		b.color = beautiful.red
	end
end)
return widget
