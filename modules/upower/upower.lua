local UPowerGlib = require("lgi").require("UPowerGlib", "1.0")

---@class upower: GearsObject_GObject, UPowerGlib.Client
local upower = _Utils.upower.gobject_to_gearsobject(UPowerGlib.Client.new())

upower._class.on_device_added = function(_, ...)
	return upower:emit_signal("device-added", ...)
end

upower._class.on_device_removed = function(_, ...)
	return upower:emit_signal("device-removed", ...)
end

return upower
