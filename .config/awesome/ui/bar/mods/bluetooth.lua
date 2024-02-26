local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local blue = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = helpers.colorizeText("󰂯", beautiful.foreground),
	widget = wibox.widget.textbox,
	valign = "center",
	align = "center",
})

awesome.connect_signal("signal::bluetooth", function(value)
	if value then
		blue.markup = helpers.colorizeText("󰂯", beautiful.blue)
	else
		blue.markup = helpers.colorizeText("󰂲", beautiful.foreground .. "99")
	end
end)

return blue
