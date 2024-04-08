local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")

local widget = wibox.widget({
	{
		{
			widget = wibox.widget.imagebox,
			image = beautiful.profile,
			forced_height = 70,
			forced_width = 70,
			opacity = 1,
			clip_shape = helpers.rrect(8),
			resize = true,
		},
		{
			{
				{
					{
						{
							max_value = 100,
							value = 69,
							id = "prog",
							forced_height = 0,
							forced_width = 80,
							paddings = 3,
							border_color = beautiful.foreground .. "99",
							background_color = beautiful.background,
							bar_shape = helpers.rrect(10),
							color = beautiful.blue,
							border_width = 1,
							shape = helpers.rrect(10),
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
						},
						spacing = 3,
						layout = wibox.layout.fixed.horizontal,
					},
					{
						font = beautiful.sans .. " 15",
						markup = helpers.colorizeText("25%", beautiful.foreground),
						id = "batvalue",
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.fixed.horizontal,
					spacing = 15,
				},
				widget = wibox.container.margin,
				left = 10,
				right = 10,
				top = 20,
				bottom = 20,
			},
			widget = wibox.container.background,
			shape = helpers.rrect(5),
			bg = beautiful.background,
		},
		layout = wibox.layout.fixed.horizontal,
		spacing = 30,
	},
	nil,
	{
		{
			{
				id = "icon",
				widget = wibox.widget.textbox,
				markup = "󰔎 ",
				font = beautiful.sans .. " 25",
			},
			widget = wibox.container.margin,
			left = 25,
			right = 10,
			top = 15,
			bottom = 15,
		},
		id = "back",
		widget = wibox.container.background,
		shape = helpers.rrect(5),
		bg = beautiful.background,
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.easy_async_with_shell("~/.config/awesome/signals/scripts/darkmode &")
			end),
		},
	},
	layout = wibox.layout.align.horizontal,
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

return widget
