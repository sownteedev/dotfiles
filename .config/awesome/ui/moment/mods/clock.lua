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
					colors = { beautiful.red },
					bg = beautiful.lighter .. "11",
					forced_width = 50,
					forced_height = 50,
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
				bg = beautiful.lighter .. "11",
				forced_width = 150,
				forced_height = 150,
			},
			nil,
			{
				{
					{
						{
							font = beautiful.sans .. " Bold 50",
							format = "%I : %M",
							align = "center",
							valign = "center",
							widget = wibox.widget.textclock,
						},
						{
							{
								font = beautiful.sans .. " Bold 10",
								format = "%p",
								align = "center",
								valign = "bottom",
								widget = wibox.widget.textclock,
							},
							widget = wibox.container.margin,
							bottom = 15,
						},
						layout = wibox.layout.fixed.horizontal,
						spacing = 10,
					},
					{
						id = "uptime",
						align = "center",
						font = beautiful.sans .. " 20",
						text = "",
						widget = wibox.widget.textbox,
					},
					spacing = 10,
					layout = wibox.layout.fixed.vertical,
				},
				widget = wibox.container.place,
				valign = "center",
				halign = "center",
			},
			layout = wibox.layout.align.horizontal,
		},
		widget = wibox.container.margin,
		left = 40,
		right = 40,
		bottom = 20,
		top = 20,
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
