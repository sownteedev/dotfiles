local awful = require("awful")
local gears = require("gears")

local function battery_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'cat /sys/class/power_supply/BAT0/capacity' &",
		function(stdout)
			local level = tonumber(string.match(stdout:match("(%d+)"), "(%d+)"))
			awesome.emit_signal("signal::battery", level)
		end
	)
end

gears.timer({
	timeout = 30,
	call_now = true,
	autostart = true,
	callback = function()
		battery_emit()
	end,
})

local function battery_status()
	awful.spawn.easy_async_with_shell(
		"bash -c 'cat /sys/class/power_supply/BAT0/status' &",
		function(stdout)
			local status = not stdout:match("Discharging")
			awesome.emit_signal("signal::batterystatus", status)
		end
	)
end
battery_status()

awful.spawn.easy_async("ps x | grep \"acpi_listen\" | grep -v grep | awk '{print $1}' | xargs kill",
	function()
		awful.spawn.with_line_callback("bash -c 'acpi_listen | grep --line-buffered ac_adapter'", {
			stdout = function(_)
				battery_status()
			end
		})
	end)
