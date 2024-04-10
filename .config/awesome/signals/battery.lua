local awful = require("awful")
local gears = require("gears")

local function battery_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'echo $(cat /sys/class/power_supply/BAT0/capacity) echo $(cat /sys/class/power_supply/BAT0/status)' &",
		function(stdout)
			local level = string.match(stdout:match("(%d+)"), "(%d+)")
			local level_int = tonumber(level)
			local power = not stdout:match("Discharging")
			awesome.emit_signal("signal::battery", level_int, power)
		end
	)
end

local function battery_status()
	awful.spawn.easy_async_with_shell("bash -c 'acpi' &", function(stdout)
		local status = not string.match(stdout, "Discharging")
		awesome.emit_signal("signal::batterystatus", status)
	end)
end

gears.timer({
	timeout = 60,
	call_now = true,
	autostart = true,
	callback = function()
		battery_emit()
	end,
})

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		battery_status()
	end,
})
