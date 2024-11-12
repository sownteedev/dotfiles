local gears = require("gears")

local upower = {}

upower.gobject_to_gearsobject = function(object)
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

return upower
