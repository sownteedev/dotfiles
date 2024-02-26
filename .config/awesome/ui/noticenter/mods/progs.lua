local helpers = require("helpers")
local beautiful = require("beautiful")
local wibox = require("wibox")

local createProgress = function(col, label, signal)
	col = col or beautiful.background
	local widget = wibox.widget({
		{
			{
				font = beautiful.sans .. " 15",
				markup = helpers.colorizeText(label, beautiful.foreground),
				widget = wibox.widget.textbox,
				valign = "start",
				align = "left",
			},
			widget = wibox.container.background,
			forced_width = 70,
		},
		{
			id = "pro",
			max_value = 100,
			value = 0,
			forced_height = 0,
			forced_width = 0,
			bar_shape = helpers.rrect(5),
			shape = helpers.rrect(5),
			color = col,
			background_color = col .. "11",
			paddings = 1,
			border_width = 1,
			widget = wibox.widget.progressbar,
		},
		layout = wibox.layout.align.horizontal,
	})
	awesome.connect_signal("signal::" .. signal, function(val)
		helpers.gc(widget, "pro").value = val
	end)
	return widget
end

local widget = {
	{
		{
			createProgress(beautiful.red, "CPU", "cpu"),
			createProgress(beautiful.blue, "MEM", "memory"),
			createProgress(beautiful.green, "DIS", "disk"),
			spacing = 25,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 30,
	},
	widget = wibox.container.background,
	bg = beautiful.background,
}

return widget
