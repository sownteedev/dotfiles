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
		handle_color = beautiful.background,
		bar_color = beautiful.background .. "00",
		bar_active_color = beautiful.foreground,
		handle_shape = createHandle(),
		handle_border_width = 3,
		handle_margins = { top = 10, right = -5, left = 1 },
		handle_border_color = beautiful.foreground,
		forced_height = 0,
		value = 25,
		maximum = 100,
		widget = wibox.widget.slider,
	})

	local slidIcon = wibox.widget({
		font = beautiful.icon .. " 25",
		markup = helpers.colorizeText(icon, beautiful.foreground),
		widget = wibox.widget.textbox,
	})

	local slidScale = wibox.widget({
		{
			{
				slidIcon,
				widget = wibox.container.place,
				valign = "start",
				align = "left",
				buttons = {
					awful.button({}, 1, function()
						awful.spawn.with_shell(cmd)
					end),
					awful.button({}, 3, function()
						awful.spawn.with_shell(cmd2)
					end),
				},
			},
			widget = wibox.container.margin,
			left = 15,
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
		spacing = 10,
	})

	awesome.connect_signal("signal::" .. signal, function(value)
		slidSlider.value = value
	end)
	awesome.connect_signal("signal::" .. signal2, function(value)
		if value and signal2 ~= "brightness" then
			if signal2 == "micmute" then
				slidIcon.markup = helpers.colorizeText(" ", beautiful.foreground)
			elseif signal2 == "volumemute" then
				slidIcon.markup = helpers.colorizeText("󰖁 ", beautiful.foreground)
			elseif value == 25 and signal2 == "brightnesss" then
				slidIcon.markup = helpers.colorizeText("󰃝 ", beautiful.foreground)
			elseif value == 70 and signal2 == "brightnesss" then
				slidIcon.markup = helpers.colorizeText(icon, beautiful.foreground)
			end
		else
			slidIcon.markup = helpers.colorizeText(icon, beautiful.foreground)
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
	spacing = 10,
})

return widget
