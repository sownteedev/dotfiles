local awful = require("awful")

function volume_emit()
	awful.spawn.easy_async_with_shell("bash -c 'pamixer --get-volume' &", function(stdout)
		local volume_int = tonumber(stdout)
		awesome.emit_signal("signal::volume", volume_int)
	end)
end

volume_emit()

local function volume_mute()
	awful.spawn.easy_async_with_shell("bash -c 'pamixer --get-mute' &", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::volumemute", status)
	end)
end
volume_mute()

local subscribe = [[bash -c "LANG=C pactl subscribe 2> /dev/null | grep --line-buffered \"Event 'change' on sink\""]]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^pactl subscribe" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			volume_mute()
		end,
	})
end)
