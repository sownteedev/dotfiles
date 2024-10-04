local awful = require("awful")

function mic()
	awful.spawn.easy_async_with_shell(
		[[pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\d+%' | awk -F'%' '{print $1}' | head -n 1]],
		function(stdout)
			local mic_int = tonumber(stdout)
			awesome.emit_signal("signal::mic", mic_int)
		end
	)
end

mic()

local function mic_mute()
	awful.spawn.easy_async_with_shell("sh -c 'pactl get-source-mute @DEFAULT_SOURCE@'", function(value)
		local boolen = value:match("yes")
		awesome.emit_signal("signal::micmute", boolen)
	end)
end
mic_mute()

function mic_toggle()
	awful.spawn.easy_async_with_shell("sh -c 'pactl get-source-mute @DEFAULT_SOURCE@'", function(stdout)
		local status = stdout:match("yes")
		awful.spawn("pactl set-source-mute @DEFAULT_SOURCE@ toggle")
		awesome.emit_signal("signal::micmute", not status)
	end)
end
