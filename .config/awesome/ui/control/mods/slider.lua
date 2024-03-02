local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local createHandle = function()
	return function(cr)
		gears.shape.rounded_rect(cr, 30, 30, 15)
	end
end

local createSlider = function(icon, signal, command)
	local slidSlider = wibox.widget({
		bar_shape = helpers.rrect(5),
		bar_height = 3,
		handle_color = beautiful.background,
		bar_color = beautiful.background .. "00",
		bar_active_color = beautiful.foreground,
		handle_shape = createHandle(),
		handle_border_width = 3,
		handle_margins = { top = 5, right = -15, left = 1 },
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
				{
					slidIcon,
					widget = wibox.container.place,
					valign = "center",
					halign = "left",
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
						bg = beautiful.background_alt,
					},
					widget = wibox.container.place,
					content_fill_horizontal = true,
					valign = "center",
				},
				slidSlider,
				layout = wibox.layout.stack,
			},
			layout = wibox.layout.fixed.horizontal,
			spacing = 20,
		},
		layout = wibox.layout.align.horizontal,
	})

	awesome.connect_signal("signal::" .. signal, function(value)
		slidSlider.value = value
	end)
	slidSlider:connect_signal("property::value", function(_, new_value)
		awful.spawn.with_shell(string.format(command, new_value))
	end)
	return slidScale
end

local widget = wibox.widget({
	{
		createSlider("󰃝 ", "brightness", "brightnessctl s %d%%"),
		createSlider(" ", "volume", "pamixer --set-volume %d"),
		createSlider(
			" ",
			"micvalue",
			"pactl set-source-volume alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__hw_sofhdadsp_6__source %d%%"
		),
		layout = wibox.layout.fixed.vertical,
		spacing = 20,
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
	bg = beautiful.background,
})

return widget
