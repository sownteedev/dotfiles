local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local createSlider = function(name, icon, signal, signal2, cmd, cmd2, command)
	local names = wibox.widget({
		markup = _Utils.widget.colorizeText(name, beautiful.foreground),
		font = beautiful.sans .. " Medium 14",
		widget = wibox.widget.textbox,
	})

	local slidSlider = wibox.widget({
		bar_height = 25,
		bar_color = beautiful.foreground .. "11",
		bar_active_color = beautiful.foreground,
		bar_shape = _Utils.widget.rrect(20),
		handle_width = 29,
		handle_shape = function(cr, width, height)
			local diameter = math.min(width, height) - 1
			cr:save()
			cr:translate((width - diameter) / 2, (height - diameter) / 2)
			gears.shape.rounded_rect(cr, diameter, diameter, diameter / 2)
			cr:restore()
		end,
		handle_color = _Utils.color.change_hex_lightness(beautiful.foreground, -10),
		handle_margins = 0,
		handle_border_color = beautiful.background .. "22",
		handle_border_width = 1,
		forced_height = 0,
		value = 25,
		maximum = 100,
		widget = wibox.widget.slider,
	})

	local slidIcon = wibox.widget({
		font = beautiful.icon .. " 18",
		markup = _Utils.widget.colorizeText(icon, beautiful.foreground),
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
							left = signal2 == "brightnesss" and 12 or 15,
							right = signal2 == "brightnesss" and 5 or 2,
							top = 8,
							bottom = 8,
						},
						id = "background_role",
						bg = beautiful.lighter1,
						widget = wibox.container.background,
						shape = _Utils.widget.rrect(30),
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
		shape = _Utils.widget.rrect(10),
		bg = beautiful.lighter,
		widget = wibox.container.background,
	})
	_Utils.widget.hoverCursor(slidSlider)
	_Utils.widget.hoverCursor(slidScale, "margin")

	local updating = false
	awesome.connect_signal("signal::" .. signal, function(value)
		updating = true
		slidSlider.value = value
		updating = false
	end)
	awesome.connect_signal("signal::" .. signal2, function(status)
		if status then
			_Utils.widget.gc(slidScale, "background_role"):set_bg(beautiful.blue)
			if signal2 == "micmute" then
				slidIcon.markup = _Utils.widget.colorizeText(" ", beautiful.lighter1)
			elseif signal2 == "volumemute" then
				slidIcon.markup = _Utils.widget.colorizeText("󰖁 ", beautiful.lighter1)
			elseif signal2 == "brightnesss" then
				slidIcon.markup = _Utils.widget.colorizeText("󰃝 ", beautiful.lighter1)
			end
		else
			slidIcon.markup = _Utils.widget.colorizeText(icon, beautiful.foreground)
			_Utils.widget.gc(slidScale, "background_role"):set_bg(beautiful.lighter1)
		end
	end)
	slidSlider:connect_signal("property::value", function(_, new_value)
		if updating then return end
		awful.spawn.with_shell(string.format(command, new_value))
		awesome.emit_signal("signal::" .. signal, new_value)
	end)
	return slidScale
end

local widget = wibox.widget({
	createSlider(
		"Display",
		"󰃠 ",
		"brightness",
		"brightnesss",
		"awesome-client 'brightness_toggle()'",
		"",
		"brightnessctl s %d%%"
	),
	createSlider(
		"Sound",
		"󰕾 ",
		"volume",
		"volumemute",
		"awesome-client 'volume_toggle()'",
		"pavucontrol",
		"pactl set-sink-volume @DEFAULT_SINK@ %d%%"
	),
	createSlider(
		"Microphone",
		" ",
		"mic",
		"micmute",
		"awesome-client 'mic_toggle()'",
		"pavucontrol",
		"pactl set-source-volume @DEFAULT_SOURCE@ %d%%"
	),
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
})

return widget
