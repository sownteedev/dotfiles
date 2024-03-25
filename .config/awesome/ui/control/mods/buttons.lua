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
						speed = 100,
						forced_width = 250,
						{
							markup = labelconnected,
							id = "label",
							font = beautiful.sans .. " 11",
							forced_width = 200,
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
		shape = helpers.rrect(5),
		bg = beautiful.background,
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.with_shell(cmd1)
			end),
			awful.button({}, 3, function()
				awful.spawn.with_shell(cmd2)
			end),
		},
	})

	awesome.connect_signal("signal::" .. signal, function(status)
		if status then
			widget:get_children_by_id("back")[1].bg = beautiful.blue
			widget:get_children_by_id("name")[1].markup = helpers.colorizeText(name, beautiful.background)
			widget:get_children_by_id("icon")[1].markup = helpers.colorizeText(icon, beautiful.background)
			if signal == "network" then
				awesome.connect_signal("signal::wifiname", function(stdout)
					if stdout ~= "" then
						widget:get_children_by_id("label")[1].markup =
							helpers.colorizeText("Connected " .. stdout, beautiful.background)
					else
						widget:get_children_by_id("label")[1].markup =
							helpers.colorizeText("No Network", beautiful.background)
					end
				end)
			elseif signal == "bluetooth" then
				awesome.connect_signal("signal::bluetoothname", function(stdout)
					if stdout ~= "" then
						widget:get_children_by_id("label")[1].markup =
							helpers.colorizeText("Connected " .. stdout, beautiful.background)
					else
						widget:get_children_by_id("label")[1].markup =
							helpers.colorizeText("No Device", beautiful.background)
					end
				end)
			else
				widget:get_children_by_id("label")[1].markup =
					helpers.colorizeText(labelconnected, beautiful.background)
			end
		else
			widget:get_children_by_id("back")[1].bg = beautiful.background
			widget:get_children_by_id("name")[1].markup = helpers.colorizeText(name, beautiful.foreground)
			widget:get_children_by_id("icon")[1].markup = helpers.colorizeText(icon, beautiful.foreground)
			widget:get_children_by_id("label")[1].markup = helpers.colorizeText(labeldisconnected, beautiful.foreground)
		end
	end)
	return widget
end

local widget = wibox.widget({
	{
		createbutton(
			"~/.config/awesome/signals/scripts/Wifi/Wifi",
			"~/.config/awesome/signals/scripts/Wifi/Menu",
			" ",
			"Network",
			"Connected",
			"Disconnected",
			"network"
		),
		createbutton(
			"~/.config/awesome/signals/scripts/Bluetooth/Bluetooth",
			"~/.config/awesome/signals/scripts/Bluetooth/Menu",
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
			"~/.config/awesome/signals/scripts/airplane",
			"",
			"󰀝 ",
			"Airplane",
			"Now In Flight Mode",
			"We're Underground",
			"airplane"
		),
		createbutton(
			"awesome-client 'naughty = require(\"naughty\") naughty.toggle()'",
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
			"~/.config/awesome/signals/scripts/redshift",
			"",
			"󰛨 ",
			"Redshift",
			"Your Eyes Are Safe",
			"Monitor Can Steal Your Eyes",
			"redshift"
		),
		createbutton(
			"~/.config/awesome/signals/scripts/Picom/toggle",
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
