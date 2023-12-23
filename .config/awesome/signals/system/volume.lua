local awful = require("awful")
local gears = require("gears")

local function volume_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'pamixer --get-volume'", function(stdout)
			local volume_int = tonumber(stdout)
			awesome.emit_signal('signal::volume', volume_int)
		end)
end

gears.timer {
	call_now = true,
	autostart = true,
	timeout = 2,
	callback = function()
		volume_emit()
	end,
	single_shot = true
}
