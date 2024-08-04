local M = {}
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local bluetooth_con
local bluetooth_dis
local bluetooth_discon
if beautiful.type == "light" then
	bluetooth_con = gears.filesystem.get_configuration_dir() .. "/themes/assets/bluetooth/bluetooth1.png"
	bluetooth_dis = gears.filesystem.get_configuration_dir() .. "/themes/assets/bluetooth/bluetooth-dis1.png"
	bluetooth_discon = gears.filesystem.get_configuration_dir() .. "/themes/assets/bluetooth/bluetooth-discon1.png"
else
	bluetooth_con = gears.filesystem.get_configuration_dir() .. "/themes/assets/bluetooth/bluetooth.png"
	bluetooth_dis = gears.filesystem.get_configuration_dir() .. "/themes/assets/bluetooth/bluetooth-dis.png"
	bluetooth_discon = gears.filesystem.get_configuration_dir() .. "/themes/assets/bluetooth/bluetooth-discon.png"
end

local bluetooth = wibox.widget({
	image = bluetooth_discon,
	resize = true,
	forced_height = 22,
	forced_width = 22,
	valign = "center",
	widget = wibox.widget.imagebox,
})
awesome.connect_signal("signal::bluetooth", function(value, _)
	if value then
		awesome.connect_signal("signal::bluetooth", function(_, name)
			if name ~= "" then
				bluetooth.image = bluetooth_con
			else
				bluetooth.image = bluetooth_discon
			end
		end)
	else
		bluetooth.image = bluetooth_dis
	end
end)

local wifi = wibox.widget({
	image = gears.color.recolor_image(
		gears.filesystem.get_configuration_dir() .. "/themes/assets/network/nowifi.png",
		beautiful.foreground .. "55"
	),
	resize = true,
	forced_height = 24,
	forced_width = 24,
	valign = "center",
	widget = wibox.widget.imagebox,
})
awesome.connect_signal("signal::network", function(_, _, quality)
	if quality == 101 then
		wifi.image = gears.filesystem.get_configuration_dir() .. "/themes/assets/network/ethernet.png"
		wifi.forced_height = 20
		wifi.forced_width = 20
	elseif quality >= 75 then
		wifi.image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "/themes/assets/network/wifi4.png", helpers.makeColor("yellow"))
	elseif quality >= 50 then
		wifi.image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "/themes/assets/network/wifi3.png", helpers.makeColor("yellow"))
	elseif quality >= 25 then
		wifi.image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "/themes/assets/network/wifi2.png", helpers.makeColor("yellow"))
	elseif quality > 0 then
		wifi.image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "/themes/assets/network/wifi1.png", helpers.makeColor("yellow"))
	else
		wifi.image = gears.color.recolor_image(
			gears.filesystem.get_configuration_dir() .. "/themes/assets/network/nowifi.png",
			beautiful.foreground .. "55"
		)
	end
end)

local battery = wibox.widget({
	{
		{
			{
				max_value = 100,
				value = 69,
				id = "prog",
				forced_height = 0,
				forced_width = 80,
				paddings = 3,
				border_color = beautiful.foreground .. "99",
				background_color = beautiful.background,
				color = beautiful.blue,
				bar_shape = helpers.rrect(7),
				border_width = 1,
				shape = helpers.rrect(10),
				widget = wibox.widget.progressbar,
			},
			widget = wibox.container.margin,
			top = 10,
			bottom = 10,
		},
		{
			{
				bg = beautiful.foreground .. "99",
				forced_height = 10,
				forced_width = 3,
				shape = helpers.rrect(10),
				widget = wibox.container.background,
			},
			widget = wibox.container.place,
		},
		spacing = 3,
		layout = wibox.layout.fixed.horizontal,
	},
	{
		{
			id = "status",
			image = nil,
			resize = true,
			forced_height = 25,
			forced_width = 25,
			halign = "center",
			widget = wibox.widget.imagebox,
		},
		widget = wibox.container.margin,
		top = 18,
		bottom = 18,
	},
	layout = wibox.layout.stack,
})

awesome.connect_signal("signal::battery", function(value)
	local b = helpers.gc(battery, "prog")
	b.value = value
	if value >= 75 then
		b.color = beautiful.green
	elseif value >= 50 then
		b.color = beautiful.blue
	elseif value >= 25 then
		b.color = beautiful.yellow
	else
		b.color = beautiful.red
	end
end)

awesome.connect_signal("signal::batterystatus", function(status)
	local b = helpers.gc(battery, "status")
	if status then
		b.image = gears.color.recolor_image(gears.filesystem.get_configuration_dir() .. "/themes/assets/thunder.png",
			beautiful.background)
	else
		b.image = nil
	end
end)

M.widget = wibox.widget({
	{
		{
			battery,
			wifi,
			bluetooth,
			spacing = 15,
			layout = wibox.layout.fixed.horizontal,
		},
		widget = wibox.container.margin,
		left = 15,
		right = 15,
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
	bg = beautiful.lighter,
	shape_border_width = beautiful.border_width_custom,
	shape_border_color = beautiful.border_color,
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::control")
			awesome.emit_signal("toggle::music")
		end),
	},
})

return M
