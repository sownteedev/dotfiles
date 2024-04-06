local M = {}
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local bluetooth = wibox.widget({
	font = beautiful.icon .. " 18",
	widget = wibox.widget.textbox,
})
awesome.connect_signal("signal::bluetooth", function(value)
	if value then
		bluetooth.markup = helpers.colorizeText("󰂯", beautiful.blue)
	else
		bluetooth.markup = helpers.colorizeText("󰂲", beautiful.foreground .. "99")
	end
end)

local wifi = wibox.widget({
	font = beautiful.icon .. " 18",
	widget = wibox.widget.textbox,
})
awesome.connect_signal("signal::quality", function(value)
	if value == 101 then
		wifi.markup = helpers.colorizeText("󰤩 ", beautiful.yellow)
	elseif value >= 75 then
		wifi.markup = helpers.colorizeText("󰤨 ", beautiful.yellow)
	elseif value >= 50 then
		wifi.markup = helpers.colorizeText("󰤥 ", beautiful.yellow)
	elseif value >= 25 then
		wifi.markup = helpers.colorizeText("󰤢 ", beautiful.yellow)
	elseif value > 0 then
		wifi.markup = helpers.colorizeText("󰤟 ", beautiful.yellow)
	else
		wifi.markup = helpers.colorizeText("󰤭 ", beautiful.foreground .. "99")
	end
end)

local battery = wibox.widget({
	{
		{
			{
				max_value = 100,
				value = 69,
				id = "prog",
				forced_height = -100,
				forced_width = 80,
				paddings = 5,
				border_color = beautiful.foreground .. "99",
				background_color = beautiful.background,
				color = beautiful.blue,
				bar_shape = helpers.rrect(5),
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
		spacing = 5,
		layout = wibox.layout.fixed.horizontal,
	},
	widget = wibox.container.margin,
	margin = 20,
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

M.widget = wibox.widget({
	{
		{
			{
				battery,
				wifi,
				bluetooth,
				spacing = 20,
				layout = wibox.layout.fixed.horizontal,
			},
			widget = wibox.container.margin,
			left = 15,
			right = 15,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(5),
		bg = beautiful.background,
		buttons = {
			awful.button({}, 1, function()
				awesome.emit_signal("toggle::control")
				awesome.emit_signal("toggle::music")
			end),
		},
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return M
