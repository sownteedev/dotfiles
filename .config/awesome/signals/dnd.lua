local gears = require("gears")
local naughty = require("naughty")

local function emit_dnd_status()
	local status = naughty.is_suspended()
	awesome.emit_signal("signal::dnd", status)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		emit_dnd_status()
	end,
})
