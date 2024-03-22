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
		bar_shape = helpers.rrect(5),
		bar_height = 3,
		bar_color = beautiful.foreground .. "05",
		bar_active_color = beautiful.foreground,
		handle_shape = createHandle(),
		handle_color = beautiful.background,
		handle_border_width = 3,
		handle_margins = { top = 15, right = -5, left = 1 },
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
				widget = wibox.container.margin,
				left = 15,
				top = 8,
				bottom = 8,
			},
			id = "background_role",
			widget = wibox.container.background,
			bg = beautiful.background,
			shape = helpers.rrect(30),
			buttons = {
				awful.button({}, 1, function()
					awful.spawn.with_shell(cmd)
				end),
				awful.button({}, 3, function()
					awful.spawn.with_shell(cmd2)
				end),
			},
		},
		{
			{
				{
					widget = wibox.container.background,
					forced_height = 2,
					shape = helpers.rrect(10),
					bg = beautiful.lighter,
				},
				widget = wibox.container.place,
				content_fill_horizontal = true,
				valign = "center",
			},
			slidSlider,
			layout = wibox.layout.stack,
		},
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
				slidScale:get_children_by_id("background_role")[1].bg = beautiful.blue
			elseif signal2 == "volumemute" then
				slidIcon.markup = helpers.colorizeText("󰖁 ", beautiful.background)
				slidScale:get_children_by_id("background_role")[1].bg = beautiful.blue
			elseif value == 25 and signal2 == "brightnesss" then
				slidIcon.markup = helpers.colorizeText("󰃝 ", beautiful.background)
				slidScale:get_children_by_id("background_role")[1].bg = beautiful.blue
			elseif value == 70 and signal2 == "brightnesss" then
				slidIcon.markup = helpers.colorizeText(icon, beautiful.foreground)
				slidScale:get_children_by_id("background_role")[1].bg = beautiful.background
			end
		else
			slidIcon.markup = helpers.colorizeText(icon, beautiful.foreground)
			slidScale:get_children_by_id("background_role")[1].bg = beautiful.background
		end
	end)
	slidSlider:connect_signal("property::value", function(_, new_value)
		awful.spawn.with_shell(string.format(command, new_value))
	end)
	return slidScale
end

local widget = wibox.widget({
	createSlider(
		"󰃠 ",
		"brightness",
		"brightnesss",
		"~/.config/awesome/signals/scripts/brightness",
		"",
		"brightnessctl s %d%%"
	),
	createSlider("󰕾 ", "volume", "volumemute", "pamixer -t", "pavucontrol", "pamixer --set-volume %d"),
	createSlider(
		" ",
		"mic",
		"micmute",
		"pactl set-source-mute @DEFAULT_SOURCE@ toggle",
		"pavucontrol",
		"pactl set-source-volume alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__hw_sofhdadsp_6__source %d%%"
	),
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
})

return widget
