local awful = require("awful")
local gears = require("gears")

-- Get volume level of mic
function update_value_of_mic()
	awful.spawn.easy_async_with_shell("bash -c 'pamixer --source 1 --get-volume'", function(stdout)
		local mic_int = tonumber(stdout)
		awesome.emit_signal("signal::micvalue", mic_int)
	end)
end

local function mic_emit()
	awful.spawn.easy_async_with_shell("bash -c 'pamixer --source 1 --get-mute'", function(value)
		local stringtoboolean = { ["true"] = true, ["false"] = false }
		value = value:gsub("%s+", "")
		value = stringtoboolean[value]
		awesome.emit_signal("signal::mic", value)
	end)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		mic_emit()
		update_value_of_mic()
	end,
})
