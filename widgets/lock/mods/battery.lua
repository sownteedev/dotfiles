local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local widget = wibox.widget({
	{
		{
			{
				max_value = 100,
				value = 69,
				id = "prog",
				forced_height = 0,
				forced_width = 200,
				paddings = 5,
				border_color = beautiful.foreground .. "99",
				background_color = beautiful.lighter .. "99",
				bar_shape = helpers.rrect(10),
				color = beautiful.blue,
				border_width = 1.25,
				shape = helpers.rrect(15),
				widget = wibox.widget.progressbar,
			},
			{
				{
					bg = beautiful.foreground .. "99",
					forced_height = 25,
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
			{
				id = "status",
				image = nil,
				resize = true,
				forced_height = 25,
				forced_width = 25,
				halign = "center",
				widget = wibox.widget.imagebox,
			},
			widget = wibox.container.margin,
			top = 20,
			bottom = 20,
		},
		layout = wibox.layout.stack,
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
	local b = helpers.gc(widget, "prog")
	local v = helpers.gc(widget, "batvalue")
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

awesome.connect_signal("signal::battery", function(_, status)
	local b = helpers.gc(widget, "status")
	if status then
		b.image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "/themes/assets/thunder.png",
			"#000000"
		)
	else
		b.image = nil
	end
end)

return widget
