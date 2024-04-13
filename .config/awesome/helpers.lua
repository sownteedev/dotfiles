local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local cairo = require("lgi").cairo
local gmatrix = require("gears.matrix")
local json = require("modules.json")

local helpers = {}

helpers.centered_client_placement = function(c)
	return gears.timer.delayed_call(function()
		awful.placement.centered(c, { honor_padding = true, honor_workarea = true })
	end)
end

helpers.rrect = function(radius)
	radius = radius or dpi(5)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

helpers.prect = function(tl, tr, br, bl, radius)
	radius = radius or dpi(5)
	return function(cr, width, height)
		gears.shape.partially_rounded_rect(cr, width, height, tl, tr, br, bl, radius)
	end
end

helpers.addHover = function(element, bg, hbg)
	element:connect_signal("mouse::enter", function()
		helpers.gc(element, "bg").bg = hbg
	end)
	element:connect_signal("mouse::leave", function()
		helpers.gc(element, "bg").bg = bg
	end)
end

helpers.placeWidget = function(widget, where, t, b, l, r)
	if where == "top_right" then
		awful.placement.top_right(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				bottom = beautiful.useless_gap * b,
				left = beautiful.useless_gap * l,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "bottom_right" then
		awful.placement.bottom_right(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				bottom = beautiful.useless_gap * b,
				left = beautiful.useless_gap * l,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "top_left" then
		awful.placement.top_left(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				bottom = beautiful.useless_gap * b,
				left = beautiful.useless_gap * l,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "bottom_left" then
		awful.placement.bottom_left(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				bottom = beautiful.useless_gap * b,
				left = beautiful.useless_gap * l,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "bottom" then
		awful.placement.bottom(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif where == "top" then
		awful.placement.top(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end
end

helpers.colorizeText = function(txt, fg)
	fg = fg or beautiful.foreground
	if fg == "" then
		fg = "#ffffff"
	end
	return "<span foreground='" .. fg .. "'>" .. txt .. "</span>"
end

helpers.cropSurface = function(ratio, surf)
	local old_w, old_h = gears.surface.get_size(surf)
	local old_ratio = old_w / old_h
	if old_ratio == ratio then
		return surf
	end

	local new_h = old_h
	local new_w = old_w
	local offset_h, offset_w = 0, 0
	-- quick mafs
	if old_ratio < ratio then
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

helpers.inTable = function(t, v)
	for _, value in ipairs(t) do
		if value == v then
			return true
		end
	end
	return false
end

helpers.hasKey = function(set, key)
	return set[key] ~= nil
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

local function get_widget_geometry(_hierarchy, widget)
	local width, height = _hierarchy:get_size()
	if _hierarchy:get_widget() == widget then
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
helpers.get_widget_geometry = function(wibox, widget)
	return get_widget_geometry(wibox._drawable._widget_hierarchy, widget)
end

helpers.randomColor = function()
	local accents = {
		helpers.makeColor("orange"),
		helpers.makeColor("cyan"),
		helpers.makeColor("purple"),
		helpers.makeColor("pink"),
		beautiful.yellow,
		beautiful.green,
		beautiful.red,
		beautiful.blue,
	}
	local i = math.random(1, #accents)
	return accents[i]
end

helpers.gc = function(widget, id)
	return widget:get_children_by_id(id)[1]
end

-- Color
local function hexToRgb(c)
	c = string.lower(c)
	return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

helpers.blend = function(foreground, background, alpha)
	alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
	local bg = hexToRgb(background)
	local fg = hexToRgb(foreground)
	local blendChannel = function(i)
		local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
		return math.floor(math.min(math.max(0, ret), 255) + 0.5)
	end

	return string.format("#%02x%02x%02x", blendChannel(1), blendChannel(2), blendChannel(3))
end

helpers.mix = function(c1, c2, wt)
	local r1 = tonumber(string.sub(c1, 2, 3), 16)
	local g1 = tonumber(string.sub(c1, 4, 5), 16)
	local b1 = tonumber(string.sub(c1, 6, 7), 16)

	local r2 = tonumber(string.sub(c2, 2, 3), 16)
	local g2 = tonumber(string.sub(c2, 4, 5), 16)
	local b2 = tonumber(string.sub(c2, 6, 7), 16)

	wt = math.min(1, math.max(0, wt))

	local nr = math.floor((1 - wt) * r1 + wt * r2)
	local ng = math.floor((1 - wt) * g1 + wt * g2)
	local nb = math.floor((1 - wt) * b1 + wt * b2)

	return string.format("#%02X%02X%02X", nr, ng, nb)
end

helpers.makeColor = function(name)
	if name == "yellow" then
		return helpers.mix(beautiful.red, beautiful.green, 0.5)
	elseif name == "orange" then
		return helpers.mix(beautiful.red, helpers.makeColor("yellow"), 0.5)
	elseif name == "cyan" then
		return helpers.mix(beautiful.green, beautiful.blue, 0.5)
	elseif name == "purple" then
		return helpers.mix(beautiful.red, beautiful.blue, 0.5)
	elseif name == "pink" then
		return helpers.mix(beautiful.red, "#ffffff", 0.5)
	end
end

helpers.makeGradient = function(color1, color2, height, width)
	return {
		type = "linear",
		from = {
			0,
			height,
		},
		to = {
			width,
			height,
		},
		stops = {
			{
				0,
				color1,
			},
			{
				1,
				color2,
			},
		},
	}
end
return helpers
