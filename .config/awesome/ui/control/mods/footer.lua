local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")

local opacity = false

local widget = wibox.widget({
	{
		layout = wibox.layout.align.horizontal,
		{
			{
				widget = wibox.widget.imagebox,
				image = beautiful.profile,
				forced_height = 50,
				forced_width = 50,
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
						spacing = 15,
					},
					widget = wibox.container.margin,
					left = 10,
					right = 10,
					top = 15,
					bottom = 15,
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
					font = beautiful.icon .. " 20",
					markup = helpers.colorizeText("󱡓 ", beautiful.foreground),
					widget = wibox.widget.textbox,
					valign = "center",
					align = "center",
				},
				widget = wibox.container.margin,
				left = 20,
				right = 15,
				top = 5,
				bottom = 5,
			},
			buttons = {
				awful.button({}, 1, function()
					opacity = not opacity
					if opacity then
						awful.spawn.with_shell("~/.config/awesome/signals/scripts/Picom/toggle --opacity &")
					else
						awful.spawn.with_shell("~/.config/awesome/signals/scripts/Picom/toggle --no-opacity &")
					end
				end),
			},
			widget = wibox.container.background,
			shape = helpers.rrect(5),
			bg = beautiful.background,
		},
	},
	widget = wibox.container.margin,
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
