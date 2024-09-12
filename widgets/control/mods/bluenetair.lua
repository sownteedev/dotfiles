local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local createbutton = function(cmd1, cmd2, icon, name, labelconnected, labeldisconnected, signal)
	local widget = wibox.widget({
		{
			{
				{
					id = "icon",
					image = gears.color.recolor_image(beautiful.icon_path .. icon, beautiful.foreground),
					resize = true,
					forced_height = 20,
					forced_width = 20,
					align = "center",
					widget = wibox.widget.imagebox,
				},
				margins = 15,
				widget = wibox.container.margin,
			},
			id = "back",
			shape = helpers.rrect(100),
			bg = helpers.change_hex_lightness(beautiful.background, 8),
			widget = wibox.container.background,
			buttons = {
				awful.button({}, 1, function()
					awful.spawn.with_shell(cmd1)
				end),
				awful.button({}, 3, function()
					awful.spawn.with_shell(cmd2)
				end),
			},
		},
		{
			{
				{
					markup = name,
					font = beautiful.sans .. " Medium 12",
					widget = wibox.widget.textbox,
				},
				{
					id = "label",
					markup = labelconnected,
					font = beautiful.sans .. " 9",
					forced_width = 230,
					forced_height = 20,
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.fixed.vertical,
			},
			halign = "left",
			valign = "center",
			widget = wibox.container.place,
		},
		spacing = 20,
		layout = wibox.layout.fixed.horizontal,
	})

	awesome.connect_signal("signal::" .. signal, function(status, _, _)
		if status then
			helpers.gc(widget, "back"):set_bg(beautiful.blue)
			helpers.gc(widget, "icon"):set_image(
				gears.color.recolor_image(
					beautiful.icon_path .. icon,
					beautiful.background
				)
			)
			if signal == "network" then
				awesome.connect_signal("signal::network", function(_, name, _)
					if name ~= "" then
						helpers
							.gc(widget, "label")
							:set_markup_silently(helpers.colorizeText(name, beautiful.foreground))
					end
				end)
			elseif signal == "bluetooth" then
				awesome.connect_signal("signal::bluetooth", function(_, name)
					if name ~= "" then
						helpers
							.gc(widget, "label")
							:set_markup_silently(helpers.colorizeText(name, beautiful.foreground))
					else
						helpers
							.gc(widget, "label")
							:set_markup_silently(helpers.colorizeText("No Device", beautiful.foreground))
					end
				end)
			else
				helpers.gc(widget, "label"):set_markup_silently(helpers.colorizeText(labelconnected, beautiful
					.foreground))
			end
		else
			helpers.gc(widget, "back"):set_bg(helpers.change_hex_lightness(beautiful.background, 8))
			helpers.gc(widget, "icon"):set_image(
				gears.color.recolor_image(
					beautiful.icon_path .. icon,
					beautiful.foreground
				)
			)
			helpers.gc(widget, "label"):set_markup_silently(helpers.colorizeText(labeldisconnected, beautiful.foreground))
		end
	end)
	helpers.hoverCursor(widget, "back")

	return widget
end


local bluenetair = wibox.widget({
	{
		{
			createbutton("awesome-client 'network_toggle()'", "", "network/wifi4.svg", "Wi-Fi", "Connected",
				"Disconnected", "network"),
			createbutton("awesome-client 'bluetooth_toggle()'", "", "bluetooth/bluetooth-macos.png", "Bluetooth",
				"Connected", "Disconnected", "bluetooth"),
			createbutton("awesome-client 'airplane_toggle()'", "", "controlcenter/airplane.svg", "Airplane", "On",
				"Off", "airplane"),
			spacing = 25,
			layout = wibox.layout.fixed.vertical,
		},
		margins = 20,
		widget = wibox.container.margin,
	},
	shape = helpers.rrect(10),
	forced_width = 225,
	bg = helpers.change_hex_lightness(beautiful.background, 4),
	widget = wibox.container.background,
})

return bluenetair
