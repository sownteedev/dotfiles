local awful = require("awful")
local gears = require("gears")

local function emit_airplane_status()
	awful.spawn.easy_async_with_shell("rfkill list | sed -n 5p | awk '{print $3}'", function(stdout)
		local status = stdout:match("yes")
		awesome.emit_signal("signal::airplane", status)
	end)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		emit_airplane_status()
	end,
})
