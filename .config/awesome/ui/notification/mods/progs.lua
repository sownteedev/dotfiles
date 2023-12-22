local helpers = require("helpers")
local beautiful = require("beautiful")
local wibox = require("wibox")

local createProgress = function(col, label, signal)
	col = col or beautiful.background
	local widget = wibox.widget {
		{
			{
				{
					font = beautiful.sans .. " 10",
					markup = helpers.colorizeText(label, beautiful.foreground),
					widget = wibox.widget.textbox,
					valign = "start",
					align = "center"
				},
				widget = wibox.container.background,
				forced_width = 50,
			},
			widget = wibox.container.margin,
			right = 10,
		},
		{
			id               = "pro",
			max_value        = 100,
			value            = 0,
			forced_height    = 20,
			forced_width     = 300,
			bar_shape        = helpers.rrect(5),
			shape            = helpers.rrect(5),
			color            = col,
			background_color = col .. '11',
			paddings         = 1,
			border_width     = 1,
			widget           = wibox.widget.progressbar,
		},
		nil,
		layout = wibox.layout.align.horizontal,
	}

	awesome.connect_signal('signal::' .. signal, function(val)
		helpers.gc(widget, "pro").value = val
	end)

	return widget
end

local widget = {
	{
		{
			createProgress(beautiful.red, "CPU", "cpu"),
			createProgress(beautiful.blue, "MEM", "memory"),
			createProgress(beautiful.red, "DIS", "disk"),
			spacing = 20,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 20
	},
	widget = wibox.container.background,
	bg = beautiful.background_alt,
}

return widget
