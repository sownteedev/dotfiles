local awful = require("awful")
local gears = require("gears")

local function wifi_name()
	awful.spawn.easy_async_with_shell("iwgetid -r", function(stdout)
		awesome.emit_signal("signal::wifiname", stdout)
	end)
end

local function emit_network_status()
	awful.spawn.easy_async_with_shell("nmcli networking connectivity check", function(stdout)
		local status = not stdout:match("none")
		awesome.emit_signal("signal::network", status)
	end)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		emit_network_status()
		wifi_name()
	end,
})
