local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local helpers = require("helpers")

local createButton = function(name, icon, cmd)
	local button = wibox.widget({
		{
			{
				{
					image = icon,
					resize = true,
					forced_height = 20,
					forced_width = 20,
					widget = wibox.widget.imagebox,
				},
				{
					text = name,
					font = beautiful.sans .. " 12",
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.fixed.horizontal,
				spacing = 20,
			},
			margins = 20,
			widget = wibox.container.margin,
		},
		bg = beautiful.lighter,
		shape = beautiful.radius,
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		widget = wibox.container.background,
		buttons = awful.button({}, 1, function()
			awful.spawn(cmd)
		end),
	})
	return button
end

awful.screen.connect_for_each_screen(function(s)
	local exit = wibox({
		screen = s,
		width = beautiful.width / 12,
		height = beautiful.height / 4.5,
		ontop = true,
		visible = false,
	})

	exit:setup({
		{
			{
				createButton("Shutdown", gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/power.png",
					"poweroff"),
				createButton("Reboot", gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/restart.png",
					"reboot"),
				createButton("Lock", gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/lock.png",
					"awesome-client \"awesome.emit_signal('toggle::lock')\" &"),
				createButton("Suspend", gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/sleep.png",
					"systemctl suspend"),
				createButton("Logout", gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/logout.png",
					"loginctl kill-user $USER"),
				layout = wibox.layout.fixed.vertical,
				spacing = 10,
			},
			widget = wibox.container.margin,
			margins = 10,
		},
		widget = wibox.container.background,
		bg = beautiful.background,
		shape = beautiful.radius,
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
	})
	helpers.placeWidget(exit, "bottom_right", 0, 2, 0, 2)
	awesome.connect_signal("toggle::exit", function()
		exit.visible = not exit.visible
	end)
	awesome.connect_signal("close::exit", function()
		exit.visible = false
	end)
end)