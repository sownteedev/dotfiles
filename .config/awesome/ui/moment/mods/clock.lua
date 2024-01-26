local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")
local gears = require("gears")

local widget = wibox.widget({
	{
		{
			{
				{
					id = "hour",
					widget = wibox.container.arcchart,
					max_value = 24,
					min_value = 0,
					padding = 0,
					value = 45,
					rounded_edge = false,
					thickness = 15,
					start_angle = math.random(250, 870) * math.pi / 180,
					colors = { beautiful.red or beautiful.violet },
					bg = beautiful.background_alt .. "11",
					forced_width = 60,
					forced_height = 60,
				},
				id = "minutes",
				widget = wibox.container.arcchart,
				max_value = 60,
				min_value = 0,
				value = 12,
				rounded_edge = false,
				thickness = 15,
				start_angle = math.random(250, 870) * math.pi / 180,
				colors = { beautiful.blue },
				bg = beautiful.background_alt .. "11",
				forced_width = 60,
				forced_height = 60,
			},
			nil,
			{
				{
					{
						font = beautiful.sans .. " Bold 35",
						format = "%I : %M",
						align = "center",
						valign = "center",
						widget = wibox.widget.textclock,
					},
					{
						id = "uptime",
						align = "center",
						font = beautiful.sans .. " 10",
						text = "",
						widget = wibox.widget.textbox,
					},
					spacing = 5,
					layout = wibox.layout.fixed.vertical,
				},
				widget = wibox.container.place,
				valign = "center",
			},
			layout = wibox.layout.align.horizontal,
		},
		widget = wibox.container.margin,
		margins = {
			top = 10,
			bottom = 10,
			left = 40,
			right = 40,
		},
	},
	shape = helpers.rrect(10),
	widget = wibox.container.background,
	bg = beautiful.background,
})

local updateTime = function()
	local time = os.date("*t")
	helpers.gc(widget, "hour").value = time.hour
	helpers.gc(widget, "minutes").value = time.min
end
awesome.connect_signal("signal::uptime", function(v)
	helpers.gc(widget, "uptime").markup = v
end)

gears.timer({
	timeout = 60,
	call_now = true,
	autostart = true,
	callback = function()
		updateTime()
	end,
})
return widget
