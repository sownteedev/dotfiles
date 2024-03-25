local awful = require("awful")
local gears = require("gears")

local function brightness()
	awful.spawn.easy_async_with_shell(
		"bash -c 'echo $(($(cat /sys/class/backlight/*/brightness) * 100 / $(cat /sys/class/backlight/*/max_brightness)))'",
		function(stdout)
			local value = tonumber(stdout)
			awesome.emit_signal("signal::brightnesss", value)
		end
	)
end

function brightness_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'echo $(($(cat /sys/class/backlight/*/brightness) * 100 / $(cat /sys/class/backlight/*/max_brightness)))'",
		function(stdout)
			local value = tonumber(stdout)
			awesome.emit_signal("signal::brightness", value)
		end
	)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		brightness_emit()
	end,
	single_shot = true,
})

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		brightness()
	end,
})
