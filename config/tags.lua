local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.tile,
}

client.connect_signal("request::manage", function(c)
	if not awesome.startup then awful.client.setslave(c) end
	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		awful.placement.no_offscreen(c)
	end
end)

screen.connect_signal("request::desktop_decoration", function(s)
	awful.tag({ "Terminal", "Browser", "Develop", "Media", "Other" }, s, awful.layout.layouts[1])
	gears.wallpaper.maximized(beautiful.wallpaper)
end)
