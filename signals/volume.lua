local awful = require("awful")

local VOLUME_CMD = "pamixer --get-volume"
local MUTE_CMD = "pamixer --get-mute"
local TOGGLE_CMD = "pamixer -t"

function volume_emit()
	awful.spawn.easy_async_with_shell(VOLUME_CMD, function(stdout)
		local volume = tonumber(stdout)
		if volume then
			awesome.emit_signal("signal::volume", volume)
		end
	end)
end

local function volume_mute()
	awful.spawn.easy_async_with_shell(MUTE_CMD, function(stdout)
		awesome.emit_signal("signal::volumemute", stdout:match("true"))
	end)
end

function volume_toggle()
	awful.spawn.easy_async_with_shell(MUTE_CMD, function(stdout)
		local current_status = stdout:match("true")
		awful.spawn.easy_async_with_shell(TOGGLE_CMD, function()
			awesome.emit_signal("signal::volumemute", not current_status)
		end)
	end)
end

volume_emit()
volume_mute()
