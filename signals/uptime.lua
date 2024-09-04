local awful = require("awful")
local gears = require("gears")

local function emit_uptime_status()
	awful.spawn.easy_async_with_shell(
		"bash -c \"uptime --pretty | sed 's/up\\s*//g'\"",
		function(stdout)
			awesome.emit_signal("signal::uptime", stdout)
		end
	)
end

gears.timer({
	timeout = 60,
	call_now = true,
	autostart = true,
	callback = function()
		emit_uptime_status()
	end,
})
