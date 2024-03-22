local awful = require("awful")
local gears = require("gears")

local function get_mute()
	awful.spawn.easy_async_with_shell("pamixer --get-mute", function(value)
		local stringtoboolean = { ["true"] = true, ["false"] = false }
		value = value:gsub("%s+", "")
		value = stringtoboolean[value]
		awesome.emit_signal("signal::volumemute", value)
	end)
end

function volume_emit()
	awful.spawn.easy_async_with_shell("pamixer --get-volume", function(stdout)
		local volume_int = tonumber(stdout)
		awesome.emit_signal("signal::volume", volume_int)
	end)
end

gears.timer({
	timeout = 0.5,
	call_now = true,
	autostart = true,
	callback = function()
		volume_emit()
	end,
	single_shot = true,
})

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		get_mute()
	end,
})
