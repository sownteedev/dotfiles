local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

return function(c)
	local titlebar = awful.titlebar(c, {
		size = 55,
		fg = beautiful.foreground,
		bg = helpers.change_hex_lightness(beautiful.background, -4),
	})

	local close = wibox.widget({
		font = beautiful.icon .. " 16",
		widget = wibox.widget.textbox,
		buttons = {
			awful.button({}, 1, function()
				c:kill()
			end),
		},
	})
	local minimize = wibox.widget({
		font = beautiful.icon .. " 16",
		widget = wibox.widget.textbox,
		buttons = {
			awful.button({}, 1, function()
				gears.timer.delayed_call(function()
					c.minimized = not c.minimized
				end)
			end),
		},
	})
	local maximize = wibox.widget({
		font = beautiful.icon .. " 16",
		widget = wibox.widget.textbox,
		buttons = {
			awful.button({}, 1, function()
				c.maximized = not c.maximized
			end),
		},
	})
	local function update_button_color()
		if client.focus ~= c then
			close.markup = helpers.colorizeText("󰅙 ", beautiful.background)
			minimize.markup = helpers.colorizeText("󰍶 ", beautiful.background)
			maximize.markup = helpers.colorizeText("󰿣 ", beautiful.background)
		else
			close.markup = helpers.colorizeText("󰅙 ", beautiful.red)
			minimize.markup = helpers.colorizeText("󰍶 ", beautiful.yellow)
			maximize.markup = helpers.colorizeText("󰿣 ", beautiful.green)
		end
	end

	c:connect_signal("focus", update_button_color)
	c:connect_signal("unfocus", update_button_color)

	awful.titlebar.enable_tooltip = false

	local icon = wibox.widget({
		{
			widget = wibox.widget.imagebox,
			image = helpers.getIcon(c, c.class, c.class),
			forced_width = 35,
			resize = true,
		},
		widget = wibox.container.place,
	})

	titlebar.widget = {
		{
			widget = wibox.container.margin,
			left = 50,
			{
				layout = wibox.layout.fixed.horizontal,
				spacing = 5,
				close,
				maximize,
				minimize,
			},
		},
		{
			{
				awful.titlebar.widget.titlewidget(c),
				left = 200,
				right = 200,
				top = 10,
				bottom = 10,
				widget = wibox.container.margin,
			},
			align = "center",
			valign = "center",
			widget = wibox.container.place,
			buttons = gears.table.join(
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
		},
		{
			icon,
			widget = wibox.container.margin,
			right = 50,
		},
		layout = wibox.layout.align.horizontal,
	}

	return titlebar
end
