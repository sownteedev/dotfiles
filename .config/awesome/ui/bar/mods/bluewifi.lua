local M = {}
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local bluetooth = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = helpers.colorizeText("󰂯", beautiful.foreground),
	widget = wibox.widget.textbox,
	valign = "center",
	align = "center",
})

awesome.connect_signal("signal::bluetooth", function(value)
	if value then
		bluetooth.markup = helpers.colorizeText("󰂯", beautiful.blue)
	else
		bluetooth.markup = helpers.colorizeText("󰂲", beautiful.foreground .. "99")
	end
end)

local wifi = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = helpers.colorizeText(" ", beautiful.foreground),
	widget = wibox.widget.textbox,
	valign = "center",
	align = "center",
})

awesome.connect_signal("signal::network", function(value)
	if value then
		wifi.markup = helpers.colorizeText(" ", beautiful.yellow)
	else
		wifi.markup = helpers.colorizeText("󰖪 ", beautiful.foreground .. "99")
	end
end)

M.bluetooth = bluetooth
M.wifi = wifi

return M
