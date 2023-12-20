local awful                  = require("awful")
local gears                  = require("gears")
local beautiful              = require("beautiful")
local wibox                  = require 'wibox'
local dpi                    = beautiful.xresources.apply_dpi
local capi                   = { client = client, mouse = mouse }
local cairo                  = require("lgi").cairo
local gmatrix                = require("gears.matrix")
local json                   = require("modules.json")

local helpers                = {}

--Shapes------------------------
--------------------------------
helpers.rrect                = function(radius)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

helpers.part_rrect           = function(tl, tr, br, bl, radius)
	return function(cr, width, height)
		gears.shape.partially_rounded_rect(cr, width, height, tl, tr, br, bl, radius)
	end
end

helpers.rbar                 = function(rad_x, rad_y)
	return function(cr, width, height)
		gears.shape.rounded_bar(cr, dpi(rad_x), dpi(rad_y))
	end
end

--Markup-------------------------
---------------------------------
helpers.mtext                = function(color, font, text)
	return '<span color="' .. color .. '" font="' .. font .. '">' .. text .. '</span>'
end

--widgets------------------------
---------------------------------
helpers.textbox              = function(color, font, text)
	return wibox.widget {
		markup = '<span color="' .. color .. '" font="' .. font .. '">' .. text .. '</span>',
		widget = wibox.widget.textbox
	}
end

helpers.imagebox             = function(img, height, width)
	return wibox.widget {
		image = img,
		resize = true,
		forced_height = dpi(height),
		forced_width = dpi(width),
		widget = wibox.widget.imagebox
	}
end

helpers.margin               = function(wgt, ml, mr, mt, mb)
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
helpers.add_hover_effect     = function(button, clr_hvr, clr_press, clr_nrml)
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
local tiling_resize_factor   = 0.01
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

helpers.rrect        = function(radius)
	radius = radius or dpi(4)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

helpers.addHover     = function(element, bg, hbg)
	element:connect_signal('mouse::enter', function(self)
		self.bg = hbg
	end)
	element:connect_signal('mouse::leave', function(self)
		self.bg = bg
	end)
end

helpers.placeWidget  = function(widget)
	if beautiful.barDir == 'left' then
		awful.placement.bottom_left(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif beautiful.barDir == 'right' then
		awful.placement.bottom_right(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif beautiful.barDir == 'bottom' then
		awful.placement.bottom(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif beautiful.barDir == 'top' then
		awful.placement.top(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end
end

helpers.prect        = function(tl, tr, br, bl, radius)
	radius = radius or dpi(4)
	return function(cr, width, height)
		gears.shape.partially_rounded_rect(cr, width, height, tl, tr, br, bl, radius)
	end
end

helpers.clickKey     = function(c, key)
	awful.spawn.with_shell("xdotool type --window " .. tostring(c.window) .. " '" .. key .. "'")
end

helpers.colorizeText = function(txt, fg)
	if fg == "" then
		fg = "#ffffff"
	end

	return "<span foreground='" .. fg .. "'>" .. txt .. "</span>"
end

helpers.cropSurface  = function(ratio, surf)
	local old_w, old_h = gears.surface.get_size(surf)
	local old_ratio = old_w / old_h
	if old_ratio == ratio then return surf end

	local new_h = old_h
	local new_w = old_w
	local offset_h, offset_w = 0, 0
	-- quick mafs
	if (old_ratio < ratio) then
		new_h = math.ceil(old_w * (1 / ratio))
		offset_h = math.ceil((old_h - new_h) / 2)
	else
		new_w = math.ceil(old_h * ratio)
		offset_w = math.ceil((old_w - new_w) / 2)
	end

	local out_surf = cairo.ImageSurface(cairo.Format.ARGB32, new_w, new_h)
	local cr = cairo.Context(out_surf)
	cr:set_source_surface(surf, -offset_w, -offset_h)
	cr.operator = cairo.Operator.SOURCE
	cr:paint()

	return out_surf
end

helpers.inTable      = function(t, v)
	for _, value in ipairs(t) do
		if value == v then
			return true
		end
	end

	return false
end


helpers.generateId = function()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format('%x', v)
	end)
end

helpers.find_last = function(haystack, needle)
	-- Set the third arg to false to allow pattern matching
	local found = haystack:reverse():find(needle:reverse(), nil, true)
	if found then
		return haystack:len() - needle:len() - found + 2
	else
		return found
	end
end



helpers.addTables = function(a, b)
	local result = {}
	for _, v in pairs(a) do
		table.insert(result, v)
	end
	for _, v in pairs(b) do
		table.insert(result, v)
	end
	return result
end

helpers.hasKey = function(set, key)
	return set[key] ~= nil
end

helpers.trim = function(string)
	return string:gsub("^%s*(.-)%s*$", "%1")
end
helpers.indexOf = function(array, value)
	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end
	return nil
end

helpers.split = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

helpers.readFile = function(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

helpers.file_exists = function(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

local function get_widget_geometry(_hierarchy, widget)
	local width, height = _hierarchy:get_size()
	if _hierarchy:get_widget() == widget then
		-- Get the extents of this widget in the device space
		local x, y, w, h = gmatrix.transform_rectangle(_hierarchy:get_matrix_to_device(), 0, 0, width, height)
		return { x = x, y = y, width = w, height = h, hierarchy = _hierarchy }
	end

	for _, child in ipairs(_hierarchy:get_children()) do
		local ret = get_widget_geometry(child, widget)
		if ret then
			return ret
		end
	end
end

function helpers.get_widget_geometry(wibox, widget)
	return get_widget_geometry(wibox._drawable._widget_hierarchy, widget)
end

function helpers.randomColor()
	local accents = {
		beautiful.magenta,
		beautiful.yellow,
		beautiful.green,
		beautiful.red,
		beautiful.blue,
	}

	local i = math.random(1, #accents)
	return accents[i]
end

helpers.readJson = function(DATA)
	if helpers.file_exists(DATA) then
		local f = assert(io.open(DATA, "rb"))
		local lines = f:read("*all")
		f:close()
		local data = json.decode(lines)
		return data
	else
		return {}
	end
end

helpers.writeJson = function(PATH, DATA)
	local w = assert(io.open(PATH, "w"))
	w:write(json.encode(DATA, nil, { pretty = true, indent = "	", align_keys = false, array_newline = true }))
	w:close()
end

-- this stands for :get_children_by_id
helpers.gc = function(widget, id)
	return widget:get_children_by_id(id)[1]
end

helpers.beginsWith = function(str, pattern)
	return str:find('^' .. pattern) ~= nil
end

return helpers
