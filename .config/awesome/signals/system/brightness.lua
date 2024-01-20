local awful = require("awful")
local gears = require("gears")

function brightness_emit()
	awful.spawn.easy_async_with_shell(
		"brightnessctl i | grep Current | awk '{print $4}' | tr -d '()%'",
		function(stdout)
			local value = tonumber(stdout)
			awesome.emit_signal("signal::brightness", value)
		end
	)
end

gears.timer({
	call_now = true,
	autostart = true,
	timeout = 1,
	callback = function()
		brightness_emit()
	end,
	single_shot = true,
})
