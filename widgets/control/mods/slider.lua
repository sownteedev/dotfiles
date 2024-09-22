local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local createSlider = function(name, icon, signal, signal2, cmd, cmd2, command)
	local names = wibox.widget({
		markup = helpers.colorizeText(name, beautiful.foreground),
		font = beautiful.sans .. " Medium 14",
		widget = wibox.widget.textbox,
	})

	local slidSlider = wibox.widget({
		bar_height = 25,
		bar_color = beautiful.foreground .. "11",
		bar_active_color = beautiful.foreground,
		bar_shape = helpers.rrect(20),
		handle_shape = function(cr)
			gears.shape.rounded_rect(cr, 28, 28, 100)
		end,
		handle_color = helpers.change_hex_lightness(beautiful.foreground, -10),
		handle_margins = { top = 8 },
		handle_border_color = beautiful.background .. "22",
		handle_border_width = 1,
		forced_height = 0,
		value = 25,
		maximum = 100,
		widget = wibox.widget.slider,
	})

	local slidIcon = wibox.widget({
		font = beautiful.icon .. " 18",
		markup = helpers.colorizeText(icon, beautiful.foreground),
		widget = wibox.widget.textbox,
	})

	local slidScale = wibox.widget({
		{
			{
				names,
				{
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
						bg = helpers.change_hex_lightness(beautiful.background, 8),
						widget = wibox.container.background,
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
					slidSlider,
					layout = wibox.layout.fixed.horizontal,
					spacing = 15,
				},
				spacing = 10,
				layout = wibox.layout.fixed.vertical,
			},
			margins = 20,
			widget = wibox.container.margin,
		},
		shape = helpers.rrect(10),
		bg = helpers.change_hex_lightness(beautiful.background, 4),
		widget = wibox.container.background,
	})
	helpers.hoverCursor(slidSlider)
	helpers.hoverCursor(slidScale, "margin")


	awesome.connect_signal("signal::" .. signal, function(value)
		slidSlider.value = value
	end)
	awesome.connect_signal("signal::" .. signal2, function(value)
		if value then
			helpers.gc(slidScale, "background_role"):set_bg(beautiful.blue)
			if signal2 == "micmute" then
				slidIcon.markup = helpers.colorizeText(" ", helpers.change_hex_lightness(beautiful.background, 8))
			elseif signal2 == "volumemute" then
				slidIcon.markup = helpers.colorizeText("󰖁 ", helpers.change_hex_lightness(beautiful.background, 8))
			elseif signal2 == "brightnesss" then
				slidIcon.markup = helpers.colorizeText("󰃝 ", helpers.change_hex_lightness(beautiful.background, 8))
				helpers.gc(slidScale, "margin").left = 12
				helpers.gc(slidScale, "margin").right = 3
			end
		else
			slidIcon.markup = helpers.colorizeText(icon, beautiful.foreground)
			helpers.gc(slidScale, "background_role"):set_bg(helpers.change_hex_lightness(beautiful.background, 8))
			if signal2 == "brightnesss" then
				helpers.gc(slidScale, "margin").left = 12
				helpers.gc(slidScale, "margin").right = 5
			end
		end
	end)
	slidSlider:connect_signal("property::value", function(_, new_value)
		awful.spawn.with_shell(string.format(command, new_value))
	end)
	return slidScale
end

local widget = wibox.widget({
	createSlider(
		"Display",
		"󰃠 ",
		"brightness",
		"brightnesss",
		"awesome-client 'brightness_toggle()' &",
		"",
		"brightnessctl s %d%% &"
	),
	createSlider("Sound", "󰕾 ", "volume", "volumemute", "pamixer -t &", "pavucontrol &", "pamixer --set-volume %d &"),
	createSlider(
		"Microphone",
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
