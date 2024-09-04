local gears = require("gears")
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local cairo = lgi.require("cairo", "1.0")
local Rsvg = lgi.require("Rsvg", "2.0")

local _Utils = {}

_Utils.gobject_to_gearsobject = function(object)
	local new_gobject = gears.object({})

	new_gobject._class = object
	new_gobject.set_class = function() end
	new_gobject.get_class = function(self)
		return self._class
	end

	new_gobject._class.on_notify = function(self, signal)
		return new_gobject:emit_signal("property::" .. signal:get_name(), self[signal:get_name()])
	end

	setmetatable(new_gobject, {
		__index = function(_, key)
			local method_value

			method_value = gears.object[key]

			if method_value then
				return method_value
			end

			method_value = new_gobject._class[key]

			if method_value then
				if type(method_value) == "userdata" then
					return function(self, ...)
						if self == new_gobject then
							return method_value(new_gobject._class, ...)
						else
							return method_value(self, ...)
						end
					end
				else
					return method_value
				end
			end
		end,
	})

	return new_gobject
end

_Utils.override = function(target, source)
	return gears.table.crush(target, source, false)
end

_Utils.capitalize = function(str)
	return (str:gsub("^%l", string.upper))
end

_Utils.recolor_image = function(image, new_color, width, height)
	if type(image) == "string" then
		width = width or 16
		height = height or 16
		local handle = Rsvg.Handle.new_from_file(image)
		local dimensions = handle:get_dimensions()

		local surface = cairo.ImageSurface.create(cairo.Format.ARGB32, width, height)
		local cr = cairo.Context(surface)

		cr:scale(width / dimensions.width, height / dimensions.height)

		handle:render_cairo(cr)

		return gears.color.recolor_image(surface, new_color)
	else
		return gears.color.recolor_image(image, new_color)
	end
end

_Utils.lookup_icon = function(args)
	if type(args) == "string" then
		return _Utils.lookup_icon({ icon_name = args })
	elseif type(args) == "table" then
		if #args >= 1 and not args.icon_name then
			local path = nil
			for _, value in ipairs(args) do
				path = _Utils.lookup_icon(value)
				if path then
					return path
				end
			end
			return
		elseif args.icon_name and type(args.icon_name) == "table" then
			local path
			for _, value in ipairs(args.icon_name) do
				path = _Utils.lookup_icon({
					icon_name = value,
					size = args.size,
					path = args.path,
					recolor = args.recolor,
				})
				if path then
					return path
				end
			end
			return
		end
	end

	if not args or not args.icon_name then
		return
	end

	args = _Utils.override({
		icon_name = "",
		size = 128,
		path = true,
		recolor = nil,
	}, args)

	local theme = Gtk.IconTheme.get_default()
	local icon_info, path

	for _, name in ipairs({
		args.icon_name,
		args.icon_name:lower(),
		args.icon_name:upper(),
		_Utils.capitalize(args.icon_name),
	}) do
		icon_info = theme:lookup_icon(name, args.size, Gtk.IconLookupFlags.USE_BUILTIN)

		if not icon_info then
			goto continue
		end

		path = icon_info:get_filename()

		if not path then
			goto continue
		end

		if args.path then
			if args.recolor ~= nil then
				return _Utils.recolor_image(path, args.recolor, args.size, args.size)
			else
				return path
			end
		else
			return icon_info
		end

		::continue::
	end
end

return _Utils
