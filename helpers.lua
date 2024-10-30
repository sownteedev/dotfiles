local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local cairo = require("lgi").cairo
local gmatrix = require("gears.matrix")
local json = require("modules.json")

local path_icon = "/home/" .. os.getenv("USER") .. "/.icons/" .. _User.IconName .. "/"
local icon_cache = {}
local DEFAULT_ICON = path_icon .. "/apps/scalable/default-application.svg"
local ICON_DIR = path_icon .. "/apps/scalable/"

local helpers = {}

local function findCustomIcon(str)
	if not str then return false, 0 end

	for i, icon in ipairs(_User.Custom_Icon) do
		if icon.name == str then
			return true, i
		end
	end
	return false, 0
end

local function findInCache(clientName)
	for _, icon in ipairs(icon_cache) do
		if icon:match(clientName) then
			return icon
		end
	end
	return nil
end

local function checkIcon(name)
	if not name then return nil end

	local fullPath = ICON_DIR .. name
	local file = io.open(fullPath, "r")

	if file then
		file:close()
		icon_cache[#icon_cache + 1] = fullPath
		return fullPath
	end
	return nil
end

helpers.getIcon = function(client, program_string, class_string)
	if not (client or program_string or class_string) then
		return client and DEFAULT_ICON
	end

	local clientName
	local isCustom, pos = findCustomIcon(class_string)

	if isCustom then
		clientName = _User.Custom_Icon[pos].to .. ".svg"
	elseif client then
		if client.class then
			clientName = string.lower(client.class:gsub(" ", "")) .. ".svg"
		elseif client.name then
			clientName = string.lower(client.name:gsub(" ", "")) .. ".svg"
		else
			return client.icon or DEFAULT_ICON
		end
	else
		clientName = (program_string or class_string) .. ".svg"
	end

	local cachedIcon = findInCache(clientName)
	if cachedIcon then return cachedIcon end

	local icon = checkIcon(clientName) or
		checkIcon(clientName:gsub("^%l", string.upper))
	if icon then return icon end

	local pngName = clientName:gsub("%.svg$", ".png")
	icon = checkIcon(pngName) or
		checkIcon(pngName:gsub("^%l", string.upper))
	if icon then return icon end

	if class_string then
		icon = checkIcon(class_string .. ".svg")
		if icon then return icon end

		icon = checkIcon(class_string .. ".png")
		if icon then return icon end
	end

	return DEFAULT_ICON
end

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

helpers.addHoverBg = function(element, id, bg, hbg)
	element:connect_signal("mouse::enter", function()
		helpers.gc(element, id).bg = hbg
	end)
	element:connect_signal("mouse::leave", function()
		helpers.gc(element, id).bg = bg
	end)
end

helpers.hoverCursor = function(widget, id)
	local oldcursor, oldwibox
	if id ~= nil then
		helpers.gc(widget, id):connect_signal("mouse::enter", function()
			local wb = mouse.current_wibox
			if wb == nil then return end
			oldcursor, oldwibox = wb.cursor, wb
			wb.cursor = "hand2"
		end)
		helpers.gc(widget, id):connect_signal("mouse::leave", function()
			if oldwibox then
				oldwibox.cursor = oldcursor
				oldwibox = nil
			end
		end)
	else
		widget:connect_signal("mouse::enter", function()
			local wb = mouse.current_wibox
			if wb == nil then return end
			oldcursor, oldwibox = wb.cursor, wb
			wb.cursor = "hand2"
		end)
		widget:connect_signal("mouse::leave", function()
			if oldwibox then
				oldwibox.cursor = oldcursor
				oldwibox = nil
			end
		end)
	end
	return widget
end

helpers.popupOpacity = function(widget, opacity)
	local function check_clients_state(clients)
		if #clients == 0 then
			return true
		end
		for _, c in ipairs(clients) do
			if not c.minimized then
				return false
			end
		end
		return true
	end

	local function update_opacity(should_be_visible)
		widget.opacity = should_be_visible and 1 or opacity
	end

	local function handle_screen_clients(s)
		if not s or not s.selected_tag then
			update_opacity(true)
			return
		end
		update_opacity(check_clients_state(s.selected_tag:clients()))
	end

	client.connect_signal("focus", function()
		update_opacity(false)
	end)

	client.connect_signal("unmanage", function(c)
		handle_screen_clients(c.screen)
	end)

	client.connect_signal("unfocus", function(c)
		handle_screen_clients(c.screen)
	end)

	tag.connect_signal("property::selected", function(t)
		update_opacity(check_clients_state(t:clients()))
	end)
end

helpers.placeWidget = function(widget, where, t, b, l, r)
	if where == "top_right" then
		awful.placement.top_right(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "bottom_right" then
		awful.placement.bottom_right(widget, {
			honor_workarea = true,
			margins = {
				bottom = beautiful.useless_gap * b,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "top_left" then
		awful.placement.top_left(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				left = beautiful.useless_gap * l,
			},
		})
	elseif where == "bottom_left" then
		awful.placement.bottom_left(widget, {
			honor_workarea = true,
			margins = {
				bottom = beautiful.useless_gap * b,
				left = beautiful.useless_gap * l,
			},
		})
	elseif where == "bottom" then
		awful.placement.bottom(widget, { honor_workarea = true, margins = beautiful.useless_gap * b })
	elseif where == "top" then
		awful.placement.top(widget, { honor_workarea = true, margins = { top = beautiful.useless_gap * t } })
	elseif where == "center" then
		awful.placement.centered(widget, { honor_workarea = true, honor_padding = true })
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
	if not surf then return nil end

	local old_w, old_h = gears.surface.get_size(surf)
	if old_w == 0 or old_h == 0 then return surf end

	local old_ratio = old_w / old_h
	if old_ratio == ratio then return surf end

	local new_w, new_h, offset_w, offset_h = old_w, old_h, 0, 0
	if old_ratio < ratio then
		new_h = math.ceil(old_w / ratio)
		offset_h = math.ceil((old_h - new_h) * 0.5)
	else
		new_w = math.ceil(old_h * ratio)
		offset_w = math.ceil((old_w - new_w) * 0.5)
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

helpers.file_exists = function(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

helpers.readFile = function(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

helpers.readJson = function(DATA)
	if not helpers.file_exists(DATA) then
		return {}
	end
	local success, f = pcall(io.open, DATA, "rb")
	if not success or not f then
		return {}
	end
	local content = f:read("*all")
	f:close()
	local success, data = pcall(json.decode, content)
	if not success then
		return {}
	end
	return data
end

helpers.writeJson = function(PATH, DATA)
	local success, w = pcall(io.open, PATH, "w")
	if not success or not w then
		return false
	end
	local json_opts = {
		pretty = true,
		indent = "\t",
		align_keys = false,
		array_newline = true
	}
	local success, encoded = pcall(json.encode, DATA, nil, json_opts)
	if not success then
		w:close()
		return false
	end

	w:write(encoded)
	w:close()
	return true
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

helpers.gc = function(widget, id)
	return widget:get_children_by_id(id)[1]
end

helpers.randomImage = function(dir)
	local IMAGE_PATTERN = "%.([jp][pn][gg]?)$"
	local files = {}
	local success, command = pcall(io.popen, "ls " .. dir)
	if not success or not command then
		return nil
	end
	for file in command:lines() do
		if file:match(IMAGE_PATTERN) then
			files[#files + 1] = file
		end
	end
	command:close()
	if #files == 0 then return nil end

	return dir .. files[math.random(#files)]
end

-------------------------- UTILS FOR COLOR -----------------------------------
local hex2rgb = function(hex)
	local hash = string.sub(hex, 1, 1) == "#"
	if string.len(hex) ~= (7 - (hash and 0 or 1)) then
		return nil
	end

	local r = tonumber(hex:sub(2 - (hash and 0 or 1), 3 - (hash and 0 or 1)), 16)
	local g = tonumber(hex:sub(4 - (hash and 0 or 1), 5 - (hash and 0 or 1)), 16)
	local b = tonumber(hex:sub(6 - (hash and 0 or 1), 7 - (hash and 0 or 1)), 16)
	return r, g, b
end

local rgb2hex = function(r, g, b)
	return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
end

local hsl2rgb_helper = function(p, q, a)
	if a < 0 then
		a = a + 6
	end
	if a >= 6 then
		a = a - 6
	end
	if a < 1 then
		return (q - p) * a + p
	elseif a < 3 then
		return q
	elseif a < 4 then
		return (q - p) * (4 - a) + p
	else
		return p
	end
end

local hsl2rgb = function(h, s, l)
	local t1, t2, r, g, b

	h = h / 60
	if l <= 0.5 then
		t2 = l * (s + 1)
	else
		t2 = l + s - (l * s)
	end

	t1 = l * 2 - t2
	r = hsl2rgb_helper(t1, t2, h + 2) * 255
	g = hsl2rgb_helper(t1, t2, h) * 255
	b = hsl2rgb_helper(t1, t2, h - 2) * 255

	return r, g, b
end

local rgb2hsl = function(r, g, b)
	local min, max, l, s, maxcolor, h
	r, g, b = r / 255, g / 255, b / 255

	min = math.min(r, g, b)
	max = math.max(r, g, b)
	maxcolor = 1 + (max == b and 2 or (max == g and 1 or 0))

	if maxcolor == 1 then
		h = (g - b) / (max - min)
	elseif maxcolor == 2 then
		h = 2 + (b - r) / (max - min)
	elseif maxcolor == 3 then
		h = 4 + (r - g) / (max - min)
	end

	if not rawequal(type(h), "number") then
		h = 0
	end

	h = h * 60

	if h < 0 then
		h = h + 360
	end

	l = (min + max) / 2

	if min == max then
		s = 0
	else
		if l < 0.5 then
			s = (max - min) / (max + min)
		else
			s = (max - min) / (2 - max - min)
		end
	end

	return h, s, l
end

local hex2hsl = function(hex)
	local r, g, b = hex2rgb(hex)
	return rgb2hsl(r, g, b)
end

local hsl2hex = function(h, s, l)
	local r, g, b = hsl2rgb(h, s, l)
	return rgb2hex(r, g, b)
end

helpers.change_hex_hue = function(hex, percent)
	local h, s, l = hex2hsl(hex)
	h = h + (percent / 100)
	if h > 360 then
		h = 360
	end
	if h < 0 then
		h = 0
	end
	return hsl2hex(h, s, l)
end

helpers.change_hex_saturation = function(hex, percent)
	local h, s, l = hex2hsl(hex)
	s = s + (percent / 100)
	if s > 1 then
		s = 1
	end
	if s < 0 then
		s = 0
	end
	return hsl2hex(h, s, l)
end

helpers.change_hex_lightness = function(hex, percent)
	if _User.Colorscheme == "light" then
		percent = -percent
	end
	local h, s, l = hex2hsl(hex)
	l = l + (percent / 100)
	if l > 1 then
		l = 1
	end
	if l < 0 then
		l = 0
	end
	return hsl2hex(h, s, l)
end

helpers.blend = function(foreground, background, alpha)
	local function hexToRgb(c)
		c = string.lower(c)
		return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
	end
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

helpers.randomColor = function()
	local c = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
	local c1 = math.random(1, #c)
	local c2 = math.random(1, #c)
	local c3 = math.random(1, #c)
	local c4 = math.random(1, #c)
	local c5 = math.random(1, #c)
	local c6 = math.random(1, #c)
	local color = "#" .. c[c1] .. c[c2] .. c[c3] .. c[c4] .. c[c5] .. c[c6]
	return color
end

function liveReload(w, properties)
	local widget = w()

	for property, arg in pairs(properties) do
		widget[property] = beautiful[arg]
	end

	awesome.connect_signal("live::reload", function()
		for property, arg in pairs(properties) do
			widget[property] = beautiful[arg]
		end
		widget:emit_signal("widget::redraw_needed")
	end)

	return widget
end

return helpers
