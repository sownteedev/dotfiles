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
	element:connect_signal("mouse::enter", function(self)
		self.bg = hbg
	end)
	element:connect_signal("mouse::leave", function(self)
		self.bg = bg
	end)
end

helpers.placeWidget = function(widget)
	if beautiful.barDir == "left" then
		awful.placement.bottom_left(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif beautiful.barDir == "right" then
		awful.placement.bottom_right(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif beautiful.barDir == "bottom" then
		awful.placement.bottom(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	elseif beautiful.barDir == "top" then
		awful.placement.top(widget, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end
end

helpers.clickKey = function(c, key)
	awful.spawn.with_shell("xdotool type --window " .. tostring(c.window) .. " '" .. key .. "'")
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

helpers.generateId = function()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format("%x", v)
	end)
end

helpers.find_last = function(haystack, needle)
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
		beautiful.violet,
		beautiful.yellow,
		beautiful.green,
		beautiful.red,
		beautiful.blue,
		beautiful.orange,
		beautiful.accent,
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

helpers.gc = function(widget, id)
	return widget:get_children_by_id(id)[1]
end

helpers.beginsWith = function(str, pattern)
	return str:find("^" .. pattern) ~= nil
end

-- Color
local function hexToRgb(c)
	c = string.lower(c)
	return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

local function rgbToHsl(r, g, b)
	r, g, b = r / 255, g / 255, b / 255
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local h, s, l
	l = (max + min) / 2
	if max == min then
		h = 0
		s = 0
	else
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	return h, s, l
end

local function hslToRgb(h, s, l)
	if s == 0 then
		return l, l, l
	end
	h = (h % 1 + 1) % 1
	s = math.min(1, math.max(0, s))
	l = math.min(1, math.max(0, l))
	local function hueToRgb(p, q, t)
		if t < 0 then
			t = t + 1
		end
		if t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		end
		if t < 1 / 2 then
			return q
		end
		if t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	local r = hueToRgb(p, q, h + 1 / 3)
	local g = hueToRgb(p, q, h)
	local b = hueToRgb(p, q, h - 1 / 3)

	return r, g, b
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

helpers.saturate = function(c, factor)
	local r = tonumber(string.sub(c, 2, 3), 16)
	local g = tonumber(string.sub(c, 4, 5), 16)
	local b = tonumber(string.sub(c, 6, 7), 16)
	local h, s, l = rgbToHsl(r, g, b)
	s = s + factor

	s = math.min(1, math.max(0, s))

	r, g, b = hslToRgb(h, s, l)
	local newHexColor = string.format("#%02X%02X%02X", r * 255, g * 255, b * 255)

	return newHexColor
end

helpers.moreRed = function(c, f)
	local r = tonumber(string.sub(c, 2, 3), 16)
	local g = tonumber(string.sub(c, 4, 5), 16)
	local b = tonumber(string.sub(c, 6, 7), 16)
	r = r + f
	r = math.min(255, math.max(0, r))
	return string.format("#%02X%02X%02X", r, g, b)
end

helpers.moreGreen = function(c, f)
	local r = tonumber(string.sub(c, 2, 3), 16)
	local g = tonumber(string.sub(c, 4, 5), 16)
	local b = tonumber(string.sub(c, 6, 7), 16)
	g = g + f
	g = math.min(255, math.max(0, g))
	return string.format("#%02X%02X%02X", r, g, b)
end

helpers.moreBlue = function(c, f)
	local r = tonumber(string.sub(c, 2, 3), 16)
	local g = tonumber(string.sub(c, 4, 5), 16)
	local b = tonumber(string.sub(c, 6, 7), 16)
	b = b + f
	b = math.min(255, math.max(0, b))
	return string.format("#%02X%02X%02X", r, g, b)
end

helpers.warm = function(c, f)
	local r = tonumber(string.sub(c, 2, 3), 16)
	local g = tonumber(string.sub(c, 4, 5), 16)
	local b = tonumber(string.sub(c, 6, 7), 16)
	r = r + f
	g = g + f
	r = math.min(255, math.max(0, r))
	g = math.min(255, math.max(0, g))
	return string.format("#%02X%02X%02X", r, g, b)
end

return helpers
