local gears = require("gears")
local cairo = require("lgi").cairo
local lgi = require("lgi")
local Rsvg = lgi.require("Rsvg", "2.0")

local image = {}

image.cropSurface = function(ratio, surf)
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

image.recolor_image = function(images, new_color, width, height)
	if type(images) == "string" then
		width = width or 16
		height = height or 16
		local handle = Rsvg.Handle.new_from_file(images)
		local dimensions = handle:get_dimensions()

		local surface = cairo.ImageSurface.create(cairo.Format.ARGB32, width, height)
		local cr = cairo.Context(surface)

		cr:scale(width / dimensions.width, height / dimensions.height)

		handle:render_cairo(cr)

		return gears.color.recolor_image(surface, new_color)
	else
		return gears.color.recolor_image(images, new_color)
	end
end

image.randomImage = function(dir)
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

return image
