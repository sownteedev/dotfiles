local awful = require("awful")
local bling = require("modules.bling")

--- Custom Layouts
local mstab = bling.layout.mstab
local centered = bling.layout.centered
local equal = bling.layout.equalarea

--- Set the layouts
tag.connect_signal("request::default_layouts", function()
	awful.layout.append_default_layouts({
		awful.layout.suit.spiral.dwindle,
		awful.layout.suit.tile,
		awful.layout.suit.floating,
		awful.layout.suit.max,
		centered,
		mstab,
		equal,
	})
end)

screen.connect_signal("request::desktop_decoration", function(s)
	awful.tag({ "1", "2" }, s, awful.layout.layouts[1])
end)
