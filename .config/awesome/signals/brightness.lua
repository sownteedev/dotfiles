local awful = require("awful")

function brightness_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'echo $(($(cat /sys/class/backlight/*/brightness) * 100 / $(cat /sys/class/backlight/*/max_brightness)))'",
		function(stdout)
			local value = tonumber(stdout)
			awesome.emit_signal("signal::brightness", value)
		end
	)
end
brightness_emit()

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

function brightness_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'brightnessctl i | grep Current'", function(status)
		status = status:match("25")
		if not status then
			awful.spawn.easy_async_with_shell("bash -c 'brightnessctl s 25% && echo true > ~/.cache/brightness'")
		else
			awful.spawn.easy_async_with_shell("bash -c 'brightnessctl s 75% && echo false > ~/.cache/brightness'")
		end
	end)
end
