local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local wifi = wibox.widget({
	font = beautiful.icon .. " 12",
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

return wifi
