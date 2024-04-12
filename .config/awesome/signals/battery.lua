local awful = require("awful")
local gears = require("gears")

local function battery_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'echo $(cat /sys/class/power_supply/BAT0/capacity) echo $(cat /sys/class/power_supply/BAT0/status)'",
		function(stdout)
			local level = tonumber(string.match(stdout:match("(%d+)"), "(%d+)"))
			local status = not stdout:match("Discharging")
			awesome.emit_signal("signal::battery", level, status)
		end
	)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		battery_emit()
	end,
})
