local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

return function(c)
	local titlebar = awful.titlebar(c, {
		size = 45,
		fg = beautiful.foreground,
		bg = helpers.change_hex_lightness(beautiful.background, -4),
	})

	local close = wibox.widget({
		{
			id = "iconbot",
			font = beautiful.icon .. " 15",
			widget = wibox.widget.textbox,
		},
		{
			id = "icon",
			font = beautiful.icon .. " 15",
			widget = wibox.widget.textbox,
		},
		layout = wibox.layout.stack,
		buttons = {
			awful.button({}, 1, function()
				c:kill()
			end),
		},
	})
	local minimize = wibox.widget({
		{
			id = "iconbot",
			font = beautiful.icon .. " 15",
			widget = wibox.widget.textbox,
		},
		{
			id = "icon",
			font = beautiful.icon .. " 15",
			widget = wibox.widget.textbox,
		},
		layout = wibox.layout.stack,
		buttons = {
			awful.button({}, 1, function()
				gears.timer.delayed_call(function()
					c.minimized = not c.minimized
				end)
			end),
		},
	})
	local maximize = wibox.widget({
		{
			id = "iconbot",
			font = beautiful.icon .. " 15",
			widget = wibox.widget.textbox,
		},
		{
			id = "icon",
			font = beautiful.icon .. " 15",
			widget = wibox.widget.textbox,
		},
		layout = wibox.layout.stack,
		buttons = {
			awful.button({}, 1, function()
				c.maximized = not c.maximized
			end),
		},
	})
	local function update_button_color()
		if client.focus ~= c then
			helpers.gc(close, "icon"):set_markup(helpers.colorizeText("󰅙 ", beautiful.background))
			helpers.gc(minimize, "icon"):set_markup(helpers.colorizeText("󰍶 ", beautiful.background))
			helpers.gc(maximize, "icon"):set_markup(helpers.colorizeText("󰿣 ", beautiful.background))
			helpers.gc(close, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.background))
			helpers.gc(minimize, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.background))
			helpers.gc(maximize, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.background))
		else
			helpers.gc(close, "icon"):set_markup(helpers.colorizeText("󰅙 ", beautiful.red))
			helpers.gc(minimize, "icon"):set_markup(helpers.colorizeText("󰍶 ", beautiful.yellow))
			helpers.gc(maximize, "icon"):set_markup(helpers.colorizeText("󰿣 ", beautiful.green))
			helpers.gc(close, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.red))
			helpers.gc(minimize, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.yellow))
			helpers.gc(maximize, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.green))
		end
	end

	close:connect_signal("mouse::enter", function()
		helpers.gc(close, "icon"):set_markup(helpers.colorizeText("󰅙 ", beautiful.red))
		helpers.gc(close, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.background))
	end)
	close:connect_signal("mouse::leave", function()
		update_button_color()
	end)
	minimize:connect_signal("mouse::enter", function()
		helpers.gc(minimize, "icon"):set_markup(helpers.colorizeText("󰍶 ", beautiful.yellow))
		helpers.gc(minimize, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.background))
	end)
	minimize:connect_signal("mouse::leave", function()
		update_button_color()
	end)
	maximize:connect_signal("mouse::enter", function()
		helpers.gc(maximize, "icon"):set_markup(helpers.colorizeText("󰿣 ", beautiful.green))
		helpers.gc(maximize, "iconbot"):set_markup(helpers.colorizeText(" ", beautiful.background))
	end)
	maximize:connect_signal("mouse::leave", function()
		update_button_color()
	end)

	c:connect_signal("focus", update_button_color)
	c:connect_signal("unfocus", update_button_color)

	local title = wibox.widget({
		markup = c.name,
		font = beautiful.sans .. " Medium 12",
		align = "center",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	c:connect_signal("property::name", function()
		title.markup = c.name
	end)

	local icon = wibox.widget({
		{
			widget = wibox.widget.imagebox,
			image = helpers.getIcon(c, c.class, c.class),
			forced_width = 35,
			resize = true,
		},
		widget = wibox.container.place,
	})

	local click_timer = nil
	local function handle_click()
		if click_timer then
			click_timer:stop()
			click_timer = nil
			c.maximized = not c.maximized
			c:raise()
		else
			if c.maximized then
				c.maximized = false
			end
			client.focus = c
			c:raise()
			awful.mouse.client.move(c)
			click_timer = gears.timer.start_new(0.3, function()
				click_timer = nil
				return false
			end)
		end
	end

	titlebar.widget = {
		{
			widget = wibox.container.margin,
			left = 30,
			{
				layout = wibox.layout.fixed.horizontal,
				spacing = 2,
				close,
				maximize,
				minimize,
			},
		},
		{
			{
				title,
				top = 5,
				bottom = 5,
				left = 200,
				right = 200,
				widget = wibox.container.margin,
			},
			id = "title",
			align = "center",
			valign = "center",
			widget = wibox.container.place,
			buttons = gears.table.join(
				awful.button({}, 1, function()
					handle_click()
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
			right = 30,
		},
		layout = wibox.layout.align.horizontal,
	}
end
