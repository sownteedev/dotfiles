local awful = require("awful")

screen.connect_signal("request::desktop_decoration", function(s)
	awful.tag({ "Terminal", "Browser", "Develop", "Media", "Other" }, s, awful.layout.layouts[1])
end)
