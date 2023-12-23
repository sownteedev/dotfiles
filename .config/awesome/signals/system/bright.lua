local awful = require("awful")
local gears = require("gears")

function update_value_of_bright()
	awful.spawn.easy_async_with_shell("brightnessctl i | grep Current | awk '{print $4}' | tr -d '()%'",
		function(stdout)
			local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
			value = tonumber(value)
			awesome.emit_signal("signal::brightness", value)
		end)
end

gears.timer {
	call_now = true,
	autostart = true,
	timeout = 2,
	callback = function()
		update_value_of_bright()
	end,
	single_shot = true
}
