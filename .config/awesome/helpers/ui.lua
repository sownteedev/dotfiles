local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local _ui = {}

function _ui.rounded_rect(radius, height, width)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

function _ui.colorizeText(txt, fg)
	if fg == "" then
		fg = beautiful.foreground
	end
	return "<span foreground='" .. fg .. "'>" .. txt .. "</span>"
end

return _ui
