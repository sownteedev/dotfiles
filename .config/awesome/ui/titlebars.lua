local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local animation = require("modules.animation")

-- titlebars --
local create_button = function(color, func)
	local widget = wibox.widget {
		widget = wibox.container.background,
		forced_height = 15,
		forced_width = 5,
		bg = color,
		buttons = {
			awful.button({}, 1, function()
				func()
			end)
		}
	}

	local widget_anim = animation:new {
		duration = 0.3,
		easing = animation.easing.linear,
		subscribed = function(h)
			widget.forced_width = h
		end }
	widget_anim:set(25)

	widget:connect_signal("mouse::enter", function()
		widget_anim:set(50)
	end)
	widget:connect_signal("mouse::leave", function()
		widget_anim:set(25)
	end)

	return widget
end

client.connect_signal("request::titlebars", function(c)
	local top_titlebar = awful.titlebar(c, {
		size = 30,
	})

	awful.titlebar.enable_tooltip = false

	local minimize = create_button(beautiful.yellow,
		function()
			gears.timer.delayed_call(function()
				c.minimized = not c.minimized
			end)
		end
	)

	local maximize = create_button(beautiful.green,
		function()
			c.maximized = not c.maximized
		end
	)

	local close = create_button(beautiful.red,
		function()
			c:kill()
		end
	)

	local function update_button_color()
		if client.focus == c then
			minimize.bg = beautiful.yellow
			maximize.bg = beautiful.green
			close.bg = beautiful.red
		else
			minimize.bg = beautiful.background_urgent
			maximize.bg = beautiful.background_urgent
			close.bg = beautiful.background_urgent
		end
	end
	c:connect_signal("focus", update_button_color)
	c:connect_signal("unfocus", update_button_color)

	local buttons = gears.table.join(
		awful.button({}, 1, function()
			client.focus = c
			c:raise()
			awful.mouse.client.move(c)
		end),
		awful.button({}, 3, function()
			client.focus = c
			c:raise()
			awful.mouse.client.resize(c)
		end)
	)

	top_titlebar.widget = {
		layout = wibox.layout.align.horizontal,
		{
			widget = wibox.container.background,
			buttons = buttons,
		},
		{
			widget = wibox.container.background,
			buttons = buttons,
		},
		{
			widget = wibox.container.place,
			valign = "top",
			{
				widget = wibox.container.margin,
				margins = { right = 30, top = 10, bottom = 10 },
				{
					layout = wibox.layout.fixed.horizontal,
					spacing = 10,
					minimize,
					maximize,
					close,
				}
			}
		},
	}
end)
