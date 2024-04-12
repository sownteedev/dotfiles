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
					font = beautiful.icon .. " 25",
					widget = wibox.widget.textbox,
				},
				{
					{
						markup = name,
						id = "name",
						font = beautiful.sans .. " 15",
						widget = wibox.widget.textbox,
					},
					{
						widget = wibox.container.scroll.horizontal,
						step_function = wibox.container.scroll.step_functions.waiting_nonlinear_back_and_forth,
						speed = 60,
						forced_width = 250,
						{
							markup = labelconnected,
							id = "label",
							font = beautiful.sans .. " 11",
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
			margins = 25,
		},
		widget = wibox.container.background,
		id = "back",
		shape = helpers.rrect(10),
		bg = beautiful.background,
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
			helpers.gc(widget, "back"):set_bg(beautiful.blue)
			helpers.gc(widget, "icon"):set_markup_silently(helpers.colorizeText(icon, beautiful.background))
			helpers.gc(widget, "name"):set_markup_silently(helpers.colorizeText(name, beautiful.background))
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
			else
				helpers.gc(widget, "label").markup = helpers.colorizeText(labelconnected, beautiful.background)
			end
		else
			helpers.gc(widget, "back").bg = beautiful.background
			helpers.gc(widget, "icon"):set_markup_silently(helpers.colorizeText(icon, beautiful.foreground))
			helpers.gc(widget, "name"):set_markup_silently(helpers.colorizeText(name, beautiful.foreground))
			helpers.gc(widget, "label").markup = helpers.colorizeText(labeldisconnected, beautiful.foreground)
		end
	end)
	return widget
end

local widget = wibox.widget({
	{
		createbutton(
			"~/.config/awesome/signals/scripts/Wifi/Wifi &",
			"~/.config/awesome/signals/scripts/Wifi/Menu &",
			" ",
			"Network",
			"Connected",
			"Disconnected",
			"network"
		),
		createbutton(
			"~/.config/awesome/signals/scripts/Bluetooth/Bluetooth &",
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
			"~/.config/awesome/signals/scripts/airplane &",
			"",
			"󰀝 ",
			"Airplane",
			"Now In Flight Mode",
			"We're Underground",
			"airplane"
		),
		createbutton(
			"awesome-client 'naughty = require(\"naughty\") naughty.toggle()' &",
			"",
			"󰍶 ",
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
			"~/.config/awesome/signals/scripts/redshift &",
			"",
			"󰛨 ",
			"Redshift",
			"Your Eyes Are Safe",
			"Monitor Can Steal Your Eyes",
			"redshift"
		),
		createbutton(
			"~/.config/awesome/signals/scripts/Picom/toggle &",
			"",
			"󱡓 ",
			"Transparency",
			"Blur So Good",
			"I Can't See You",
			"transparency"
		),
		spacing = 15,
		layout = wibox.layout.flex.horizontal,
	},
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
})

return widget
