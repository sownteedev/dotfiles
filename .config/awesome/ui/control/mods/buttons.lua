local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")

local createbutton = function(cmd1, cmd2, icon, name, labelconnected, labeldisconnected, signal)
	local widget = wibox.widget({
		{
			{
				{
					{
						markup = icon,
						id = "icon",
						font = beautiful.icon .. " 30",
						widget = wibox.widget.textbox,
					},
					{
						{
							markup = name,
							id = "name",
							font = beautiful.sans .. " 20",
							widget = wibox.widget.textbox,
						},
						{
							markup = labelconnected,
							id = "label",
							font = beautiful.sans .. " 10",
							widget = wibox.widget.textbox,
						},
						layout = wibox.layout.fixed.vertical,
						spacing = 10,
					},
					layout = wibox.layout.fixed.horizontal,
					spacing = 20,
				},
				nil,
				{
					markup = "󰅂",
					font = beautiful.icon .. " 15",
					id = "arr",
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.align.horizontal,
			},
			widget = wibox.container.margin,
			top = 30,
			bottom = 30,
			left = 30,
			right = 30,
		},
		widget = wibox.container.background,
		id = "back",
		shape = helpers.rrect(5),
		bg = beautiful.background_alt,
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
			widget:get_children_by_id("arr")[1].markup = helpers.colorizeText("󰅂", beautiful.background)
			widget:get_children_by_id("name")[1].markup = helpers.colorizeText(name, beautiful.background)
			widget:get_children_by_id("icon")[1].markup = helpers.colorizeText(icon, beautiful.background)
			widget:get_children_by_id("label")[1].markup = helpers.colorizeText(labelconnected, beautiful.background)
		else
			widget:get_children_by_id("back")[1].bg = beautiful.background_alt .. "aa"
			widget:get_children_by_id("arr")[1].markup = helpers.colorizeText("󰅂", beautiful.foreground)
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
			"~/.config/awesome/signals/scripts/Wifi/Wifi --toggle",
			"~/.config/awesome/signals/scripts/Wifi/Menu",
			" ",
			"Network",
			"Connected",
			"Disconnected",
			"network"
		),
		createbutton(
			"~/.config/awesome/signals/scripts/Bluetooth/Bluetooth --toggle",
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
			"~/.config/awesome/signals/scripts/airplane --toggle",
			"",
			"󰀝 ",
			"Airplane",
			"Now In Flight Mode",
			"Turned Off",
			"airplane"
		),
		createbutton(
			"awesome-client 'naughty = require(\"naughty\") naughty.toggle()'",
			"",
			"󰍶 ",
			"Don't Disturb",
			"Turned On",
			"Turned Off",
			"dnd"
		),
		spacing = 15,
		layout = wibox.layout.flex.horizontal,
	},
	{
		createbutton(
			"~/.config/awesome/signals/scripts/redshift --toggle",
			"",
			"󰛨 ",
			"Redshift",
			"Your Eyes Are Safe",
			"Night Light Is Off",
			"redshift"
		),
		createbutton("pamixer --source 59 -t", "", " ", "Microphone", "It's Muted", "It's Turned On", "mic"),
		spacing = 15,
		layout = wibox.layout.flex.horizontal,
	},
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
})

return widget
