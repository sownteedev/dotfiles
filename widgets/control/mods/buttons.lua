local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")

local createbutton = function(cmd1, cmd2, icon, name, labelconnected, labeldisconnected, signal)
	local widget = wibox.widget({
		{
			{
				{
					markup = icon,
					id = "icon",
					font = beautiful.icon .. " 23",
					widget = wibox.widget.textbox,
				},
				{
					{
						markup = name,
						id = "name",
						font = beautiful.sans .. " Medium 14",
						widget = wibox.widget.textbox,
					},
					{
						widget = wibox.container.scroll.horizontal,
						step_function = wibox.container.scroll.step_functions.waiting_nonlinear_back_and_forth,
						speed = 40,
						forced_width = 250,
						{
							markup = labelconnected,
							id = "label",
							font = beautiful.sans .. " 10",
							forced_width = 230,
							forced_height = 20,
							widget = wibox.widget.textbox,
						},
					},
					layout = wibox.layout.fixed.vertical,
					spacing = 10,
				},
				layout = wibox.layout.fixed.horizontal,
				spacing = 15,
			},
			widget = wibox.container.margin,
			margins = 20,
		},
		widget = wibox.container.background,
		id = "back",
		shape = helpers.rrect(10),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.easy_async_with_shell(cmd1)
			end),
			awful.button({}, 3, function()
				awful.spawn.easy_async_with_shell(cmd2)
			end),
		},
	})

	awesome.connect_signal("signal::" .. signal, function(status, _, _)
		if status then
			helpers.gc(widget, "back"):set_bg(helpers.makeGradient(beautiful.red, beautiful.blue, "FF", 0, 250))
			helpers.gc(widget, "icon"):set_markup_silently(helpers.colorizeText(icon, beautiful.background))
			helpers.gc(widget, "name"):set_markup_silently(helpers.colorizeText(name, beautiful.background))
			helpers.gc(widget, "label"):set_markup_silently(helpers.colorizeText(labelconnected, beautiful.background))
			if signal == "network" then
				awesome.connect_signal("signal::network", function(_, name, _)
					if name ~= "" then
						helpers
							.gc(widget, "label")
							:set_markup_silently(helpers.colorizeText(name, beautiful.background))
					end
				end)
			elseif signal == "bluetooth" then
				awesome.connect_signal("signal::bluetooth", function(_, name)
					if name ~= "" then
						helpers
							.gc(widget, "label")
							:set_markup_silently(helpers.colorizeText("Connected " .. name, beautiful.background))
					else
						helpers
							.gc(widget, "label")
							:set_markup_silently(helpers.colorizeText("No Device", beautiful.background))
					end
				end)
			end
		else
			helpers.gc(widget, "back"):set_bg(beautiful.lighter)
			helpers.gc(widget, "label"):set_markup_silently(helpers.colorizeText(labeldisconnected, beautiful.foreground))
			helpers.gc(widget, "icon"):set_markup_silently(helpers.colorizeText(icon, beautiful.foreground))
			helpers.gc(widget, "name"):set_markup_silently(helpers.colorizeText(name, beautiful.foreground))
		end
	end)
	return widget
end

local widget = wibox.widget({
	{
		createbutton(
			"awesome-client 'network_toggle()' &",
			"~/.config/awesome/signals/scripts/Wifi/Menu &",
			" ",
			"Network",
			"Connected",
			"Disconnected",
			"network"
		),
		createbutton(
			"awesome-client 'bluetooth_toggle()' &",
			"~/.config/awesome/signals/scripts/Bluetooth/Menu &",
			" ",
			"Bluetooth",
			"Connected",
			"Disconnected",
			"bluetooth"
		),
		spacing = 15,
		layout = wibox.layout.flex.horizontal,
	},
	{
		createbutton(
			"awesome-client 'airplane_toggle()' &",
			"",
			"󰀝 ",
			"Airplane",
			"Now In Flight Mode",
			"We're Underground",
			"airplane"
		),
		createbutton(
			"awesome-client 'dnd_toggle()' &",
			"",
			"󱏧 ",
			"Disturb",
			"Don't Disturb Me",
			"Disturb Me Please",
			"dnd"
		),
		spacing = 15,
		layout = wibox.layout.flex.horizontal,
	},
	{
		createbutton(
			"awesome-client 'redshift_toggle()' &",
			"",
			"󰛨 ",
			"Night Light",
			"Your Eyes Are Safe",
			"Monitor Can Steal Your Eyes",
			"redshift"
		),
		createbutton(
			"awesome-client 'blur_toggle()' &",
			"",
			"󱡓 ",
			"Blur Effect",
			"Blur So Good",
			"I Can't See You",
			"blur"
		),
		spacing = 15,
		layout = wibox.layout.flex.horizontal,
	},
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
})

return widget
