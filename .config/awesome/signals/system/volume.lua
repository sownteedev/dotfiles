local awful = require("awful")
local gears = require("gears")

function update_value_of_volume()
	awful.spawn.easy_async_with_shell(
		"pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1 && pactl get-sink-mute @DEFAULT_SINK@ | grep -o -E 'yes|no' | head -1",
		function(stdout)
			local value, muted = string.match(stdout, '(%d+)\n(%a+)')
			value = tonumber(value)
			local icon = ""
			if value == 0 or muted == "yes" then
				icon = "󰖁 "
			elseif value <= 33 then
				icon = " "
			elseif value <= 66 then
				icon = "󰕾 "
			elseif value <= 100 then
				icon = " "
			else
				icon = "󱄡 "
			end
			awesome.emit_signal("volume::value", value, icon)
		end)
end

local function volume_emit()
	awful.spawn.easy_async_with_shell(
		"bash -c 'pamixer --get-volume'", function(stdout)
			local volume_int = tonumber(stdout)
			awesome.emit_signal('signal::volume', volume_int)
		end)
end

gears.timer {
	call_now = true,
	autostart = true,
	timeout = 2,
	callback = function()
		update_value_of_volume()
		volume_emit()
	end,
	single_shot = true
}
