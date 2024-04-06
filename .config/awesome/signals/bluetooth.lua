local awful = require("awful")
local gears = require("gears")

local function emit_bluetooth_status()
	awful.spawn.easy_async_with_shell("bash -c 'bluetoothctl show | grep -i powered:'", function(stdout)
		local status = stdout:match("yes")
		awesome.emit_signal("signal::bluetooth", status)
	end)
	awful.spawn.easy_async_with_shell(
		"bash -c \"bluetoothctl info | grep -i Name: | cut -d ' ' -f 2-\"",
		function(stdout)
			awesome.emit_signal("signal::bluetoothname", stdout:gsub("%s+", ""))
		end
	)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		emit_bluetooth_status()
	end,
})
