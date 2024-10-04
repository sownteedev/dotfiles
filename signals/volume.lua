local awful = require("awful")

function volume_emit()
	awful.spawn.easy_async_with_shell("sh -c 'pamixer --get-volume'", function(stdout)
		local volume_int = tonumber(stdout)
		awesome.emit_signal("signal::volume", volume_int)
	end)
end

volume_emit()

local function volume_mute()
	awful.spawn.easy_async_with_shell("sh -c 'pamixer --get-mute'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::volumemute", status)
	end)
end
volume_mute()

function volume_toggle()
	awful.spawn.easy_async_with_shell("sh -c 'pamixer --get-mute'", function(stdout)
		local status = stdout:match("true")
		awful.spawn("pamixer -t")
		awesome.emit_signal("signal::volumemute", not status)
	end)
end
