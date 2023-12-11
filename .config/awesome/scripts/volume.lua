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

function update_value_of_capture()
	awful.spawn.easy_async_with_shell("pactl get-source-volume @DEFAULT_SOURCE@ | grep -Po '[0-9]{1,3}(?=%)' | head -1",
		function(stdout)
			local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
			value = tonumber(value)
			awesome.emit_signal("capture::value", value)
		end)
end

function update_value_of_capture_muted()
	awful.spawn.easy_async_with_shell("pactl get-source-mute @DEFAULT_SOURCE@ | grep -o -E 'yes|no' | head -1",
		function(stdout)
			local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
			awesome.emit_signal("capture_muted::value", value)
		end)
end

function updateVolumeSignals()
	update_value_of_volume()
	update_value_of_capture_muted()
end

gears.timer {
	call_now = true,
	autostart = true,
	timeout = 2,
	callback = updateVolumeSignals,
	single_shot = true
}
