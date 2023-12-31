local awful        = require("awful")
local wibox        = require("wibox")
local helpers      = require("helpers")
local beautiful    = require("beautiful")

local createbutton = function(cmd, icon, name, labelconnected, labeldisconnected, signal)
	local widget = wibox.widget {
		{
			{
				{
					{
						markup = icon,
						id     = "icon",
						font   = beautiful.icon .. " 20",
						widget = wibox.widget.textbox,
					},
					{
						{
							markup = name,
							id     = "name",
							font   = beautiful.sans .. " 11",
							widget = wibox.widget.textbox,
						},
						{
							markup = labelconnected,
							id     = "label",
							font   = beautiful.sans .. " 8",
							widget = wibox.widget.textbox,
						},
						layout = wibox.layout.fixed.vertical,
						spacing = 5
					},
					layout = wibox.layout.fixed.horizontal,
				},
				nil,
				{
					markup = "󰅂",
					font   = beautiful.icon .. " 12",
					id     = "arr",
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.align.horizontal,
				spacing = 5
			},
			widget = wibox.container.margin,
			top = 15,
			bottom = 15,
			left = 15,
			right = 15
		},
		widget = wibox.container.background,
		id = "back",
		shape = helpers.rrect(5),
		bg = beautiful.background_alt,
		buttons = { awful.button({}, 1, function()
			awful.spawn.with_shell(cmd)
		end) }
	}
	awesome.connect_signal('signal::' .. signal, function(status)
		if status then
			widget:get_children_by_id("back")[1].bg = beautiful.blue
			widget:get_children_by_id("arr")[1].markup = helpers.colorizeText("󰅂", beautiful.background)
			widget:get_children_by_id("name")[1].markup = helpers.colorizeText(name, beautiful.background)
			widget:get_children_by_id("icon")[1].markup = helpers.colorizeText(icon, beautiful.background)
			widget:get_children_by_id("label")[1].markup = helpers.colorizeText(labelconnected, beautiful.background)
		else
			widget:get_children_by_id("back")[1].bg = beautiful.background_alt .. 'aa'
			widget:get_children_by_id("arr")[1].markup = helpers.colorizeText("󰅂", beautiful.foreground)
			widget:get_children_by_id("name")[1].markup = helpers.colorizeText(name, beautiful.foreground)
			widget:get_children_by_id("icon")[1].markup = helpers.colorizeText(icon, beautiful.foreground)
			widget:get_children_by_id("label")[1].markup = helpers.colorizeText(labeldisconnected, beautiful.foreground)
		end
	end)
	return widget
end

local widget       = wibox.widget {
	{
		createbutton("~/.config/awesome/signals/scripts/wifi --toggle", "󰖩 ", "Network", "Connected", "Disconnected",
			"network"),
		createbutton("~/.config/awesome/signals/scripts/bluetooth --toggle", "󰂯 ", "Bluetooth", "Connected", "Disconnected",
			"bluetooth"),
		spacing = 10,
		layout = wibox.layout.flex.horizontal
	},
	{
		createbutton("~/.config/awesome/signals/scripts/airplane --toggle", "󰀝 ", "Airplane", "Now In Flight Mode",
			"Turned Off", "airplane"),
		createbutton('awesome-client \'naughty = require("naughty") naughty.toggle()\'', "󰍶 ", "Don't Disturb",
			"Turned On", "Turned Off", "dnd"),
		spacing = 10,
		layout = wibox.layout.flex.horizontal
	},
	{
		createbutton("~/.config/awesome/signals/scripts/redshift --toggle", "󰛨 ", "Redshift", "Your Eyes Are Safe",
			"Night Light Is Off", "redshift"),
		createbutton('pamixer --source 1 -t', "󰍬 ", "Microphone",
			"It's Muted", "It's Turned On", "mic"),
		spacing = 10,
		layout = wibox.layout.flex.horizontal
	},
	layout = wibox.layout.fixed.vertical,
	spacing = 15
}

return widget
