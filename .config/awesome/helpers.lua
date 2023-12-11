local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local wibox = require 'wibox'
local dpi = beautiful.xresources.apply_dpi
local capi = { client = client, mouse = mouse }

local helpers = {}

--Shapes------------------------
--------------------------------
helpers.rrect = function(radius)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

helpers.part_rrect = function(tl, tr, br, bl, radius)
	return function(cr, width, height)
		gears.shape.partially_rounded_rect(cr, width, height, tl, tr, br, bl, radius)
	end
end

helpers.rbar = function(rad_x, rad_y)
	return function(cr, width, height)
		gears.shape.rounded_bar(cr, dpi(rad_x), dpi(rad_y))
	end
end

--Markup-------------------------
---------------------------------
helpers.mtext = function(color, font, text)
	return '<span color="' .. color .. '" font="' .. font .. '">' .. text .. '</span>'
end

--widgets------------------------
---------------------------------
helpers.textbox = function(color, font, text)
	return wibox.widget {
		markup = '<span color="' .. color .. '" font="' .. font .. '">' .. text .. '</span>',
		widget = wibox.widget.textbox
	}
end

helpers.imagebox = function(img, height, width)
	return wibox.widget {
		image = img,
		resize = true,
		forced_height = dpi(height),
		forced_width = dpi(width),
		widget = wibox.widget.imagebox
	}
end

helpers.margin = function(wgt, ml, mr, mt, mb)
	return wibox.widget {
		wgt,
		widget = wibox.container.margin,
		left = dpi(ml),
		right = dpi(mr),
		top = dpi(mt),
		bottom = dpi(mb),
	}
end

--Hover_effects---------------------
------------------------------------
helpers.add_hover_effect = function(button, clr_hvr, clr_press, clr_nrml)
	button:connect_signal("mouse::enter", function()
		button.bg = clr_hvr
	end)

	button:connect_signal("mouse::leave", function()
		button.bg = clr_nrml
	end)

	button:connect_signal("button::press", function()
		button.bg = clr_press
	end)

	button:connect_signal("button::release", function()
		button.bg = clr_hvr
	end)
end

--Client---------------------------

local floating_resize_amount = 20
local tiling_resize_factor = 0.01
function helpers.resize_client(c, direction)
	if c and c.floating or awful.layout.get(capi.mouse.screen) == awful.layout.suit.floating then
		if direction == "up" then
			c:relative_move(0, 0, 0, -floating_resize_amount)
		elseif direction == "down" then
			c:relative_move(0, 0, 0, floating_resize_amount)
		elseif direction == "left" then
			c:relative_move(0, 0, -floating_resize_amount, 0)
		elseif direction == "right" then
			c:relative_move(0, 0, floating_resize_amount, 0)
		end
	elseif awful.layout.get(capi.mouse.screen) ~= awful.layout.suit.floating then
		if direction == "up" then
			awful.client.incwfact(-tiling_resize_factor)
		elseif direction == "down" then
			awful.client.incwfact(tiling_resize_factor)
		elseif direction == "left" then
			awful.tag.incmwfact(-tiling_resize_factor)
		elseif direction == "right" then
			awful.tag.incmwfact(tiling_resize_factor)
		end
	end
end

-- Move client to screen edge, respecting the screen workarea
function helpers.move_to_edge(c, direction)
	local workarea = awful.screen.focused().workarea
	if direction == "up" then
		c:geometry({ nil, y = workarea.y + beautiful.useless_gap * 2, nil, nil })
	elseif direction == "down" then
		c:geometry({
			nil,
			y = workarea.height
				+ workarea.y
				- c:geometry().height
				- beautiful.useless_gap * 2
				- beautiful.border_width * 2,
			nil,
			nil,
		})
	elseif direction == "left" then
		c:geometry({ x = workarea.x + beautiful.useless_gap * 2, nil, nil, nil })
	elseif direction == "right" then
		c:geometry({
			x = workarea.width
				+ workarea.x
				- c:geometry().width
				- beautiful.useless_gap * 2
				- beautiful.border_width * 2,
			nil,
			nil,
			nil,
		})
	end
end

-- Move client DWIM (Do What I Mean)
-- Move to edge if the client / layout is floating
-- Swap by index if maximized
-- Else swap client by direction
function helpers.move_client(c, direction)
	if c.floating or (awful.layout.get(capi.mouse.screen) == awful.layout.suit.floating) then
		helpers.move_to_edge(c, direction)
	elseif awful.layout.get(capi.mouse.screen) == awful.layout.suit.max then
		if direction == "up" or direction == "left" then
			awful.client.swap.byidx(-1, c)
		elseif direction == "down" or direction == "right" then
			awful.client.swap.byidx(1, c)
		end
	else
		awful.client.swap.bydirection(direction, c, nil)
	end
end

function helpers.centered_client_placement(c)
	return gears.timer.delayed_call(function()
		awful.placement.centered(c, { honor_padding = true, honor_workarea = true })
	end)
end

-- Resize gaps on the fly
helpers.resize_gaps = function(amt)
	local t = awful.screen.focused().selected_tag
	t.gap = t.gap + tonumber(amt)
	awful.layout.arrange(awful.screen.focused())
end

-- Resize padding on the fly
helpers.resize_padding = function(amt)
	local s = awful.screen.focused()
	local l = s.padding.left
	local r = s.padding.right
	local t = s.padding.top
	local b = s.padding.bottom
	s.padding = {
		left = l + amt,
		right = r + amt,
		top = t + amt,
		bottom = b + amt,
	}
	awful.layout.arrange(awful.screen.focused())
end

-- UI  ----------------------------
function helpers.rounded_rect(radius, height, width)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

function helpers.colorizetext(txt, fg)
	if fg == "" then
		fg = beautiful.foreground
	end
	return "<span foreground='" .. fg .. "'>" .. txt .. "</span>"
end

return helpers
