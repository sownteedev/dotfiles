local awful = require("awful")
local gears = require("gears")

local function emit_network_status()
	awful.spawn.easy_async_with_shell("bash -c 'nmcli networking connectivity check'", function(stdout)
		local status = not stdout:match("none")
		awesome.emit_signal("signal::network", status)
	end)
	awful.spawn.easy_async_with_shell(
		"bash -c 'iwgetid -r ; nmcli -t -f DEVICE,TYPE con show --active ; nmcli networking connectivity check'",
		function(stdout)
			if stdout:match("limited") or stdout:match("Error:") then
				stdout = "Wifi or Ethernet no network"
			elseif stdout:match("full") and stdout:match("ethernet") then
				stdout = "Connected Ethernet"
			else
				stdout = "Connected " .. stdout
			end
			awesome.emit_signal("signal::wifiname", stdout)
		end
	)
	awful.spawn.easy_async_with_shell("bash -c 'iwconfig ; nmcli -t -f DEVICE,TYPE con show --active'", function(stdout)
		if stdout:match("ethernet") then
			awesome.emit_signal("signal::quality", 101)
		elseif stdout:match("Quality") then
			local quality = stdout:match("Quality=(%d+)")
			awesome.emit_signal("signal::quality", (quality * 10) / 7)
		else
			awesome.emit_signal("signal::quality", 0)
		end
	end)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		emit_network_status()
	end,
})
