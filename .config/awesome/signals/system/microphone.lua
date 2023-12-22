local awful = require('awful')
local gears = require('gears')

-- Get volume level of mic
function update_value_of_capture()
	awful.spawn.easy_async_with_shell("pactl get-source-volume @DEFAULT_SOURCE@ | grep -Po '[0-9]{1,3}(?=%)' | head -1",
		function(stdout)
			local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
			value = tonumber(value)
			awesome.emit_signal("capture::value", value)
		end)
end

local function mic_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'pamixer --source 1 --get-mute'", function(value)
			local stringtoboolean = { ["true"] = true, ["false"] = false }
			value = value:gsub("%s+", "")
			value = stringtoboolean[value]
			awesome.emit_signal('signal::mic', value)
		end)
end

gears.timer {
	timeout   = 0,
	call_now  = true,
	autostart = true,
	callback  = function()
		mic_emit()
	end
}
