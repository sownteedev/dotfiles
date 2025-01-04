local beautiful = require("beautiful")

local color = {}

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

--- MAIN ---
color.change_hex_hue = function(hex, percent)
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

color.change_hex_saturation = function(hex, percent)
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

color.change_hex_lightness = function(hex, percent)
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

color.blend = function(foreground, background, alpha)
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

color.mix = function(c1, c2, wt)
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

color.randomColor = function()
	local c = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
	local c1 = math.random(1, #c)
	local c2 = math.random(1, #c)
	local c3 = math.random(1, #c)
	local c4 = math.random(1, #c)
	local c5 = math.random(1, #c)
	local c6 = math.random(1, #c)
	local colors = "#" .. c[c1] .. c[c2] .. c[c3] .. c[c4] .. c[c5] .. c[c6]
	return colors
end

return color
