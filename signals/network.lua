local awful = require("awful")
local gears = require("gears")

local function emit_network_status()
	awful.spawn.easy_async_with_shell(
		"bash -c 'iwgetid -r ; nmcli -t -f DEVICE,TYPE con show --active ; nmcli networking connectivity check ; iwconfig'",
		function(stdout)
			local status = not stdout:match("none") and not stdout:match("limited")

			local name = nil
			if stdout:match("Error:") then
				name = "Error Network"
			elseif stdout:match("full") and stdout:match("ethernet") then
				name = "Ethernet"
			elseif stdout:match("limited") then
				name = "No Network"
			else
				name = stdout
			end

			local quality = nil
			if stdout:match("ethernet") then
				quality = 101
			elseif stdout:match("Quality") then
				local qua = stdout:match("Quality=(%d+)")
				quality = (qua * 10) / 7
			else
				quality = 0
			end

			awesome.emit_signal("signal::network", status, name, quality)
		end
	)
end

gears.timer({
	timeout = 5,
	call_now = true,
	autostart = true,
	callback = function()
		emit_network_status()
	end,
})

function network_toggle()
	awful.spawn.easy_async_with_shell("bash -c \"nmcli | grep wlp0s20f3 | awk 'FNR == 1'\"", function(status)
		status = status:match("connected")
		awful.spawn.with_shell(status and "bash -c 'nmcli networking off'" or "bash -c 'nmcli networking on'")
	end)
end
