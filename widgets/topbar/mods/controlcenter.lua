local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local helpers = require("helpers")

local controlcenter = wibox.widget({
	image = gears.color.recolor_image(
		beautiful.icon_path .. "controlcenter/controlcenter.svg",
		beautiful.foreground
	),
	resize = true,
	forced_height = 20,
	forced_width = 20,
	valign = "center",
	widget = wibox.widget.imagebox,
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::control")
		end),
	},
})

local spotlight = wibox.widget({
	image = gears.color.recolor_image(
		beautiful.icon_path .. "controlcenter/magnifying.png",
		beautiful.foreground
	),
	resize = true,
	forced_height = 20,
	forced_width = 20,
	valign = "center",
	widget = wibox.widget.imagebox,
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("toggle::launcher")
		end),
	},
})

local wifi = wibox.widget({
	image = gears.color.recolor_image(
		beautiful.icon_path .. "network/nowifi.svg",
		beautiful.foreground
	),
	resize = true,
	forced_height = 20,
	forced_width = 20,
	valign = "center",
	widget = wibox.widget.imagebox,
	buttons = {
		awful.button({}, 1, function()
			awful.spawn.with_shell("awesome-client 'network_toggle()")
		end),
	}
})
awesome.connect_signal("signal::network", function(_, _, quality)
	if quality == 101 then
		wifi.image = gears.color.recolor_image(
			beautiful.icon_path .. "network/ethernet-macos.png",
			beautiful.foreground
		)
	elseif quality >= 75 then
		wifi.image = gears.color.recolor_image(
			beautiful.icon_path .. "/network/wifi4.svg", beautiful.foreground)
	elseif quality >= 50 then
		wifi.image = gears.color.recolor_image(
			beautiful.icon_path .. "network/wifi3.svg", beautiful.foreground)
	elseif quality >= 25 then
		wifi.image = gears.color.recolor_image(
			beautiful.icon_path .. "network/wifi2.svg", beautiful.foreground)
	elseif quality > 0 then
		wifi.image = gears.color.recolor_image(
			beautiful.icon_path .. "network/wifi1.svg", beautiful.foreground)
	else
		wifi.image = gears.color.recolor_image(
			beautiful.icon_path .. "network/nowifi.svg", beautiful.foreground)
	end
end)


local bluetooth = wibox.widget({
	image = gears.color.recolor_image(
		beautiful.icon_path .. "bluetooth/bluetooth-discon-macos.png",
		beautiful.foreground
	),
	resize = true,
	forced_height = 20,
	forced_width = 20,
	valign = "center",
	widget = wibox.widget.imagebox,
	buttons = {
		awful.button({}, 1, function()
			awful.spawn.with_shell("awesome-client 'bluetooth_toggle()'")
		end),
	}
})
awesome.connect_signal("signal::bluetooth", function(status, _)
	if status then
		awesome.connect_signal("signal::bluetooth", function(_, name)
			if name ~= "" then
				bluetooth.image = gears.color.recolor_image(beautiful.icon_path .. "bluetooth/bluetooth-macos.png",
					beautiful.foreground)
			else
				bluetooth.image = gears.color.recolor_image(
					beautiful.icon_path .. "bluetooth/bluetooth-discon-macos.png",
					beautiful.foreground)
			end
		end)
	else
		bluetooth.image = gears.color.recolor_image(beautiful.icon_path .. "bluetooth/bluetooth-dis-macos.png",
			beautiful.foreground)
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
				forced_width = 50,
				paddings = 3,
				border_color = beautiful.foreground .. "99",
				background_color = beautiful.background .. "00",
				color = beautiful.foreground,
				bar_shape = helpers.rrect(5),
				border_width = 1,
				shape = helpers.rrect(7),
				widget = wibox.widget.progressbar,
			},
			widget = wibox.container.margin,
			top = 10,
			bottom = 10,
		},
		{
			{
				bg = beautiful.foreground .. "99",
				forced_height = 7,
				forced_width = 2,
				shape = beautiful.radius,
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
			halign = "center",
			widget = wibox.widget.imagebox,
		},
		widget = wibox.container.margin,
		top = 15,
		bottom = 15,
	},
	layout = wibox.layout.stack,
})
awesome.connect_signal("signal::battery", function(value)
	helpers.gc(battery, "prog").value = value
end)
awesome.connect_signal("signal::batterystatus", function(status)
	local b = helpers.gc(battery, "status")
	if status then
		b.image = gears.color.recolor_image(beautiful.icon_path .. "popup/charge.svg",
			beautiful.green)
	else
		b.image = nil
	end
end)

local layout = awful.widget.layoutbox({
	buttons = {
		awful.button({
			modifiers = {},
			button = 1,
			on_press = function()
				awful.layout.inc(1)
			end,
		}),
		awful.button({
			modifiers = {},
			button = 3,
			on_press = function()
				awful.layout.inc(-1)
			end,
		}),
	},
})
local layouts = {
	layout,
	top = 10,
	bottom = 10,
	widget = wibox.container.margin,
}

local systray = wibox.widget({
	{
		base_size = 25,
		widget = wibox.widget.systray,
	},
	widget = wibox.container.place,
	valign = "center",
})

local widget = wibox.widget({
	systray,
	battery,
	wifi,
	bluetooth,
	spotlight,
	controlcenter,
	layouts,
	spacing = 25,
	layout = wibox.layout.fixed.horizontal,
})

-- Add widget when it enable
local micmuted = wibox.widget({
	image = gears.color.recolor_image(
		beautiful.icon_path .. "awm/micmuted.svg",
		beautiful.foreground
	),
	resize = true,
	forced_height = 20,
	forced_width = 20,
	valign = "center",
	widget = wibox.widget.imagebox,
})

local addedmicmuted = false
awesome.connect_signal("signal::micmute", function(value)
	if value and not addedmicmuted then
		widget:insert(1, micmuted)
		addedmicmuted = true
	elseif not value and addedmicmuted then
		for i, v in ipairs(widget.children) do
			if v == micmuted then
				widget:remove(i)
				break
			end
		end
		addedmicmuted = false
	end
end)

local volmuted = wibox.widget({
	image = gears.color.recolor_image(
		beautiful.icon_path .. "awm/volumemuted.svg",
		beautiful.foreground
	),
	resize = true,
	forced_height = 20,
	forced_width = 20,
	valign = "center",
	widget = wibox.widget.imagebox,
})

local addedvolmuted = false
awesome.connect_signal("signal::volumemute", function(value)
	if value and not addedvolmuted then
		widget:insert(1, volmuted)
		addedvolmuted = true
	elseif not value and addedvolmuted then
		for i, v in ipairs(widget.children) do
			if v == volmuted then
				widget:remove(i)
				break
			end
		end
		addedvolmuted = false
	end
end)

helpers.hoverCursor(systray)
helpers.hoverCursor(battery)
helpers.hoverCursor(wifi)
helpers.hoverCursor(bluetooth)
helpers.hoverCursor(spotlight)
helpers.hoverCursor(controlcenter)
helpers.hoverCursor(layout)
helpers.hoverCursor(volmuted)
helpers.hoverCursor(micmuted)

return widget
