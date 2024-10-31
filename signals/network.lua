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

local function emit_network_status()
	kill_last_process()

	awful.spawn.easy_async_with_shell([[
        sh -c '
        echo $$ > /tmp/network_status_pid
        iwgetid -r
        nmcli -t -f DEVICE,TYPE con show --active
        nmcli networking connectivity check
        iwconfig
        rm -f /tmp/network_status_pid
        ']], function(stdout)
		awful.spawn.easy_async("cat /tmp/network_status_pid", function(pid)
			last_pid = pid:gsub("%s+", "")
		end)

		local status = not stdout:match("none") and not stdout:match("limited")

		local name = stdout:match("Error:") and "Error Network"
			or (stdout:match("full") and stdout:match("ethernet") and "Ethernet")
			or (stdout:match("limited") and "No Network")
			or stdout:match("^[^\n]+") or ""

		local quality = stdout:match("ethernet") and 101
			or (stdout:match("Quality") and ((stdout:match("Quality=(%d+)") * 10) / 7))
			or 0

		awesome.emit_signal("signal::network", status, name, quality)
	end)
end

local update_timer = gears.timer({
	timeout = 10,
	autostart = false,
	callback = emit_network_status
})

awesome.connect_signal("exit", function()
	kill_last_process()
	update_timer:stop()
end)

function network_toggle()
	awful.spawn.easy_async_with_shell(
		"nmcli | grep wlp0s20f3 | awk 'FNR == 1'",
		function(status)
			local is_connected = status:match("connected")
			awful.spawn.easy_async_with_shell(
				is_connected and "nmcli networking off" or "nmcli networking on",
				function()
					gears.timer.start_new(1, function()
						emit_network_status()
						return false
					end)
				end
			)
		end
	)
end

update_timer:start()
emit_network_status()