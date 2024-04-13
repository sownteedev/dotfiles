local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local createHandle = function()
	return function(cr)
		gears.shape.rounded_rect(cr, 20, 20, 15)
	end
end

local createSlider = function(icon, signal, signal2, cmd, cmd2, command)
	local slidSlider = wibox.widget({
		bar_height = 3,
		bar_color = beautiful.foreground .. "05",
		bar_active_color = beautiful.foreground,
		handle_shape = createHandle(),
		handle_color = beautiful.background,
		handle_border_width = 3,
		handle_margins = { top = 13, right = -5, left = 1 },
		handle_border_color = beautiful.foreground,
		forced_height = 0,
		value = 25,
		maximum = 100,
		widget = wibox.widget.slider,
	})

	local slidIcon = wibox.widget({
		font = beautiful.icon .. " 20",
		markup = helpers.colorizeText(icon, beautiful.foreground),
		widget = wibox.widget.textbox,
	})

	local slidScale = wibox.widget({
		{
			{
				slidIcon,
				id = "margin",
				widget = wibox.container.margin,
				left = 15,
				right = 2,
				top = 8,
				bottom = 8,
			},
			id = "background_role",
			widget = wibox.container.background,
			bg = beautiful.background,
			shape = helpers.rrect(30),
			buttons = {
				awful.button({}, 1, function()
					awful.spawn.easy_async_with_shell(cmd)
				end),
				awful.button({}, 3, function()
					awful.spawn.easy_async_with_shell(cmd2)
				end),
			},
		},
		slidSlider,
		layout = wibox.layout.fixed.horizontal,
		spacing = 15,
	})

	awesome.connect_signal("signal::" .. signal, function(value)
		slidSlider.value = value
	end)
	awesome.connect_signal("signal::" .. signal2, function(value)
		if value then
			if signal2 == "micmute" then
				slidIcon.markup = helpers.colorizeText(" ", beautiful.background)
				helpers.gc(slidScale, "background_role"):set_bg(beautiful.blue)
			elseif signal2 == "volumemute" then
				slidIcon.markup = helpers.colorizeText("󰖁 ", beautiful.background)
				helpers.gc(slidScale, "background_role"):set_bg(beautiful.blue)
			elseif signal2 == "brightnesss" then
				slidIcon.markup = helpers.colorizeText("󰃝 ", beautiful.background)
				helpers.gc(slidScale, "background_role"):set_bg(beautiful.blue)
				helpers.gc(slidScale, "margin").left = 10
				helpers.gc(slidScale, "margin").right = 5
			end
		else
			slidIcon.markup = helpers.colorizeText(icon, beautiful.foreground)
			helpers.gc(slidScale, "background_role"):set_bg(beautiful.background)
			if signal2 == "brightnesss" then
				helpers.gc(slidScale, "margin").left = 12
				helpers.gc(slidScale, "margin").right = 5
			end
		end
	end)
	slidSlider:connect_signal("property::value", function(_, new_value)
		awful.spawn.easy_async_with_shell(string.format(command, new_value))
	end)
	return slidScale
end

local widget = wibox.widget({
	createSlider(
		"󰃠 ",
		"brightness",
		"brightnesss",
		"awesome-client 'brightness_toggle()' &",
		"",
		"brightnessctl s %d%% &"
	),
	createSlider("󰕾 ", "volume", "volumemute", "pamixer -t &", "pavucontrol &", "pamixer --set-volume %d &"),
	createSlider(
		" ",
		"mic",
		"micmute",
		"pactl set-source-mute @DEFAULT_SOURCE@ toggle &",
		"pavucontrol &",
		"pactl set-source-volume @DEFAULT_SOURCE@ %d%% &"
	),
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
})

return widget
