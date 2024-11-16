local awful = require("awful")

local VOLUME_CMD = "pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | tr -d '%'"
local MUTE_CMD = "pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}'"
local TOGGLE_CMD = "pactl set-sink-mute @DEFAULT_SINK@ toggle"

function volume_emit()
	awful.spawn.easy_async_with_shell(VOLUME_CMD, function(stdout)
		local volume = tonumber(stdout)
		if volume then
			awesome.emit_signal("signal::volume", volume)
		end
	end)
end

awful.spawn.easy_async_with_shell(MUTE_CMD, function(stdout)
	awesome.emit_signal("signal::volumemute", stdout:match("yes"))
end)

function volume_toggle()
	awful.spawn.easy_async_with_shell(MUTE_CMD, function(stdout)
		local current_status = stdout:match("yes")
		awful.spawn.easy_async_with_shell(TOGGLE_CMD, function()
			awesome.emit_signal("signal::volumemute", not current_status)
		end)
	end)
end

volume_emit()
