local awful = require("awful")
local gears = require("gears")

local last_pid = nil

local function kill_last_process()
	if last_pid then
		awful.spawn.easy_async("sh -c 'kill " .. last_pid .. " 2>/dev/null'", function()
			last_pid = nil
		end)
	end
end

local function emit_bluetooth_status()
	kill_last_process()

	awful.spawn.easy_async_with_shell([[
		sh -c '
		echo $$ > /tmp/bluetooth_status_pid
		(bluetoothctl show | grep -i powered:) & (bluetoothctl info) & wait
		rm -f /tmp/bluetooth_status_pid
		']], function(stdout)
		awful.spawn.easy_async("cat /tmp/bluetooth_status_pid", function(pid)
			last_pid = pid:gsub("%s+", "")
		end)

		local status = stdout:match("yes")
		local name = stdout:match("Name: ([^\n]+)") or ""

		awesome.emit_signal("signal::bluetooth", status, name)
	end)
end

local update_timer = gears.timer({
	timeout = 10,
	autostart = false,
	callback = emit_bluetooth_status
})

awesome.connect_signal("exit", function()
	kill_last_process()
	update_timer:stop()
end)

function bluetooth_toggle()
	awful.spawn.easy_async_with_shell(
		"bluetoothctl show | grep -i powered:",
		function(stdout)
			local is_powered = stdout:match("yes")
			awful.spawn.easy_async_with_shell(
				is_powered and "bluetoothctl power off" or "bluetoothctl power on",
				function()
					gears.timer.start_new(1, function()
						emit_bluetooth_status()
						return false
					end)
				end
			)
		end
	)
end

update_timer:start()
emit_bluetooth_status()
