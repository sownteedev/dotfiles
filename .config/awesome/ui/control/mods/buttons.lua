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
						font   = beautiful.icon_font .. " 18",
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
						spacing = 0
					},
					layout = wibox.layout.fixed.horizontal,
					spacing = 10
				},
				nil,
				{
					markup = "󰅂",
					font   = beautiful.icon_font .. " 12",
					id     = "arr",
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.align.horizontal,
			},
			widget = wibox.container.margin,
			top = 12,
			bottom = 12,
			left = 15,
			right = 15
		},
		widget = wibox.container.background,
		id = "back",
		shape = helpers.rrect(8),
		bg = beautiful.background_alt,
		buttons = { awful.button({}, 1, function()
			awful.spawn.with_shell(cmd)
		end) }
	}
	awesome.connect_signal('signal::' .. signal, function(status)
		if status then
			widget:get_children_by_id("back")[1].bg = beautiful.blue
			widget:get_children_by_id("arr")[1].markup = helpers.colorizetext("󰅂", beautiful.background)
			widget:get_children_by_id("name")[1].markup = helpers.colorizetext(name, beautiful.background)
			widget:get_children_by_id("icon")[1].markup = helpers.colorizetext(icon, beautiful.background)
			widget:get_children_by_id("label")[1].markup = helpers.colorizetext(labelconnected, beautiful.background)
		else
			widget:get_children_by_id("back")[1].bg = beautiful.background_alt .. 'aa'
			widget:get_children_by_id("arr")[1].markup = helpers.colorizetext("󰅂", beautiful.foreground .. 'cc')
			widget:get_children_by_id("name")[1].markup = helpers.colorizetext(name, beautiful.foreground .. 'cc')
			widget:get_children_by_id("icon")[1].markup = helpers.colorizetext(icon, beautiful.foreground .. 'cc')
			widget:get_children_by_id("label")[1].markup = helpers.colorizetext(labeldisconnected,
				beautiful.foreground .. 'cc')
		end
	end)
	return widget
end

local widget       = wibox.widget {
	{
		createbutton("~/.config/awesome/signals/scripts/wifi --toggle", "󰤨 ", "Network", "Connected", "Disconnected",
			"network"),
		createbutton("~/.config/awesome/signals/scripts/bluetooth --toggle", "󰂯 ", "Bluetooth", "Connected", "Disconnected",
			"bluetooth"),
		spacing = 15,
		layout = wibox.layout.flex.horizontal
	},
	{
		createbutton("~/.config/awesome/signals/scripts/airplanemode --toggle", "󰀝 ", "Airplane Mode", "Now In Flight Mode",
			"Turned Off", "airplane"),
		createbutton('awesome-client \'naughty = require("naughty") naughty.toggle()\'', "󰍶 ", "Do Not Disturb",
			"Turned On", "Turned Off", "dnd"),
		spacing = 15,
		layout = wibox.layout.flex.horizontal
	},
	{
		createbutton("~/.config/awesome/signals/scripts/redshift --toggle", "󰛨 ", "Redshift", "Your Eyes Are Safe",
			"Night Light Is Off", "redshift"),
		createbutton('pamixer --source 1 -t', "󰍬 ", "Microphone",
			"It's Muted", "It Is Turned On", "mic"),
		spacing = 15,
		layout = wibox.layout.flex.horizontal
	},
	layout = wibox.layout.fixed.vertical,
	spacing = 20
}

return widget
