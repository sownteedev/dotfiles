local awful = require("awful")
local gears = require("gears")

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

local function brightnesss()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/brightness'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::brightnesss", status)
	end)
end

brightnesss()
local subscribe = [[bash -c 'while (inotifywait -e modify ~/.cache/brightness -qq) do echo; done']]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^inotifywait" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			brightnesss()
		end,
	})
end)
