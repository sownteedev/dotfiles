local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local animation = require("modules.animation")
local getIcon = require("modules.getIcon")
local dpi = beautiful.xresources.apply_dpi

local create_button = function(color, func)
	local widget = wibox.widget({
		widget = wibox.container.background,
		forced_height = 8,
		shape = helpers.rrect(3),
		bg = color,
		buttons = {
			awful.button({}, 1, function()
				func()
			end),
		},
	})

	local widget_anim = animation:new({
		duration = 0.3,
		easing = animation.easing.linear,
		subscribed = function(h)
			widget.forced_width = h
		end,
	})
	widget_anim:set(30)

	widget:connect_signal("mouse::enter", function()
		widget_anim:set(60)
	end)
	widget:connect_signal("mouse::leave", function()
		widget_anim:set(30)
	end)

	return widget
end

client.connect_signal("request::titlebars", function(c)
	local top_titlebar = awful.titlebar(c, {
		size = 35,
	})

	awful.titlebar.enable_tooltip = false

	local minimize = create_button(beautiful.yellow, function()
		gears.timer.delayed_call(function()
			c.minimized = not c.minimized
		end)
	end)

	local maximize = create_button(beautiful.green, function()
		c.maximized = not c.maximized
	end)

	local close = create_button(beautiful.red, function()
		c:kill()
	end)

	local icon = wibox.widget({
		{
			{
				{
					widget = wibox.widget.imagebox,
					image = getIcon(c, c.class, c.class),
					forced_width = 40,
					resize = true,
				},
				widget = wibox.container.place,
				halign = "center",
			},
			margins = dpi(5),
			widget = wibox.container.margin,
		},
		bg = beautiful.background_dark,
		shape = helpers.rrect(5),
		widget = wibox.container.background,
	})

	local function update_button_color()
		if client.focus == c then
			minimize.bg = beautiful.yellow
			maximize.bg = beautiful.green
			close.bg = beautiful.red
		else
			minimize.bg = beautiful.background
			maximize.bg = beautiful.background
			close.bg = beautiful.background
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
			widget = wibox.container.place,
			{
				widget = wibox.container.margin,
				left = 30,
				{
					layout = wibox.layout.fixed.horizontal,
					spacing = 10,
					close,
					maximize,
					minimize,
				},
			},
		},
		{
			widget = wibox.container.background,
			buttons = buttons,
		},
		{
			icon,
			widget = wibox.container.margin,
			right = 10,
		},
	}
end)
