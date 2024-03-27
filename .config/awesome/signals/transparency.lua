local awful = require("awful")
local gears = require("gears")

local function trans_emit()
	awful.spawn.easy_async_with_shell("cat ~/.cache/transparency", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::transparency", status)
	end)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		trans_emit()
	end,
})
