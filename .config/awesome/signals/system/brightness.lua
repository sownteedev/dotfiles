local awful = require("awful")
local gears = require("gears")

local function brightness()
	awful.spawn.easy_async_with_shell(
		"brightnessctl i | grep Current | awk '{print $4}' | tr -d '()%'",
		function(stdout)
			local value = tonumber(stdout)
			awesome.emit_signal("signal::brightnesss", value)
		end
	)
end

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
	timeout = 0.5,
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
