local awful = require("awful")
local gears = require("gears")

local function emit_bluetooth_status()
	awful.spawn.easy_async_with_shell(
		"sh -c 'bluetoothctl show | grep -i powered: ; bluetoothctl info'",
		function(stdout)
			local status = stdout:match("yes")
			local name = stdout:match("Name: ([^\n]+)")
			if not name then
				name = ""
			end
			awesome.emit_signal("signal::bluetooth", status, name)
		end
	)
end

gears.timer({
	timeout = 5,
	call_now = true,
	autostart = true,
	callback = function()
		emit_bluetooth_status()
	end,
})

function bluetooth_toggle()
	awful.spawn.easy_async_with_shell("sh -c 'bluetoothctl show | grep Powered'", function(status)
		status = status:match("yes")
		awful.spawn(status and "sh -c 'bluetoothctl power off'" or "sh -c 'bluetoothctl power on'")
	end)
end
