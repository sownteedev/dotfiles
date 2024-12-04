local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local function create_button(icon, color, action)
	local button = wibox.widget({
		{
			{
				{
					image = gears.color.recolor_image(icon, color),
					resize = true,
					widget = wibox.widget.imagebox,
				},
				margins = 9,
				widget = wibox.container.margin,
			},
			id = "bg",
			shape = _Utils.widget.rrect(5),
			widget = wibox.container.background,
		},
		margins = 5,
		widget = wibox.container.margin,
		buttons = {
			awful.button({}, 1, action),
		},
	})
	button:connect_signal("mouse::enter", function()
		_Utils.widget.gc(button, "bg"):set_bg(_Utils.color.blend(color, beautiful.lighter, 0.5))
	end)
	button:connect_signal("mouse::leave", function()
		_Utils.widget.gc(button, "bg"):set_bg(beautiful.lighter)
	end)

	return button
end

return function(c)
	local buttons = {
		close = create_button(beautiful.icon_path .. "button/close.svg", beautiful.red, function() c:kill() end),
		minimize = create_button(beautiful.icon_path .. "button/minus.svg", beautiful.yellow, function()
			gears.timer.delayed_call(function()
				c.minimized = not c.minimized
			end)
		end),
		maximize = create_button(beautiful.icon_path .. "button/maximize.svg", beautiful.green,
			function() c.maximized = not c.maximized end),
	}

	local title = wibox.widget({
		markup = c.name,
		font = beautiful.sans .. " 11",
		align = "center",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	c:connect_signal("property::name", function() title.markup = c.name end)

	local icon = wibox.widget({
		widget = wibox.widget.imagebox,
		image = _Utils.icon.getIcon(c, c.class, c.class),
		forced_width = 30,
		valign = "center",
		resize = true,
	})

	local click_timer = nil
	local function handle_click()
		if click_timer then
			click_timer:stop()
			click_timer = nil
			c.maximized = true
			c:raise()
		else
			client.focus = c
			c:raise()
			if c.maximized then
				c.maximized = false
			end
			awful.mouse.client.move(c)
			click_timer = gears.timer.start_new(0.3, function()
				click_timer = nil
				return false
			end)
		end
	end

	awful.titlebar(c, {
		size = 40,
		bg = beautiful.lighter,
	}):setup {
		{
			widget = wibox.container.margin,
			left = 15,
			icon,
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
			align = "center",
			valign = "center",
			widget = wibox.container.place,
			buttons = gears.table.join(
				awful.button({}, 1, handle_click),
				awful.button({}, 3, function()
					client.focus = c
					c:raise()
					awful.mouse.client.resize(c)
				end)
			)
		},
		{
			{
				spacing = -5,
				layout = wibox.layout.fixed.horizontal,
				buttons.minimize,
				buttons.maximize,
				buttons.close,
			},
			widget = wibox.container.margin,
			right = 5,
		},
		layout = wibox.layout.align.horizontal,
	}
end
