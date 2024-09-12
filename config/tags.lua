local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")

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

client.connect_signal("request::titlebars", function(c)
	if c.requests_no_titlebar then return end
	require("widgets.titlebar")(c)
end)

screen.connect_signal("request::desktop_decoration", function(s)
	awful.tag({ "Terminal", "Browser", "Develop", "Media", "Other" }, s, awful.layout.layouts[1])
	s.bar = require("widgets.topbar")(s)

	s.dock = require("widgets.dock")(s)
	s.control = require("widgets.control")(s)
	s.exit = require("widgets.exit")(s)
	s.noticenter = require("widgets.noticenter")(s)
	s.lock = require("widgets.lock")(s)

	s.calendar = require("widgets.popup.calendar")(s)
	s.image = require("widgets.popup.image")(s)
	s.music = require("widgets.popup.music")(s)
	s.system = require("widgets.popup.system")(s)
	s.weather = require("widgets.popup.weather")(s)
	s.battery = require("widgets.popup.battery")(s)
	s.brivol = require("widgets.popup.brivolmic")(s)
end)

gears.wallpaper.maximized(beautiful.wallpaper)
