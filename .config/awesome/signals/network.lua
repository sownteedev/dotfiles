local awful = require("awful")
local gears = require("gears")

local function emit_network_status()
	awful.spawn.easy_async_with_shell(
		"bash -c 'iwgetid -r ; nmcli -t -f DEVICE,TYPE con show --active ; nmcli networking connectivity check ; iwconfig'",
		function(stdout)
			local status = not stdout:match("none")

			local name = nil
			if stdout:match("Error:") then
				name = "Wifi or Ethernet no network"
			elseif stdout:match("full") and stdout:match("ethernet") then
				name = "Connected Ethernet"
			else
				name = "Connected " .. stdout
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
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		emit_network_status()
	end,
})
