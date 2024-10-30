local awful = require("awful")

local MIC_VOLUME_CMD = "pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\\b\\d+(?=%)' | head -n 1"
local MIC_MUTE_CMD = "pactl get-source-mute @DEFAULT_SOURCE@"
local MIC_TOGGLE_CMD = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"

function mic()
	awful.spawn.easy_async_with_shell(MIC_VOLUME_CMD, function(stdout)
		local volume = tonumber(stdout)
		if volume then
			awesome.emit_signal("signal::mic", volume)
		end
	end)
end

local function mic_mute()
	awful.spawn.easy_async_with_shell(MIC_MUTE_CMD, function(stdout)
		awesome.emit_signal("signal::micmute", stdout:match("yes"))
	end)
end

function mic_toggle()
	awful.spawn.easy_async_with_shell(MIC_MUTE_CMD, function(stdout)
		local current_status = stdout:match("yes")
		awful.spawn.easy_async_with_shell(MIC_TOGGLE_CMD, function()
			awesome.emit_signal("signal::micmute", not current_status)
		end)
	end)
end

mic()
mic_mute()
