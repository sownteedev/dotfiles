local awful = require("awful")
local gears = require("gears")

local AIRPLANE_CACHE = gears.filesystem.get_cache_dir() .. "airplane"
local AIRPLANE_STATUS_CMD = "cat " .. AIRPLANE_CACHE
local RFKILL_STATUS_CMD = "rfkill list | sed -n 5p"

local function get_toggle_cmd(enable)
	return string.format(
		"rfkill %s all && echo %s > %s",
		enable and "block" or "unblock",
		enable and "true" or "false",
		AIRPLANE_CACHE
	)
end

awful.spawn.easy_async_with_shell(AIRPLANE_STATUS_CMD, function(stdout)
	awesome.emit_signal("signal::airplane", stdout == "true\n")
end)

function airplane_toggle()
	awful.spawn.easy_async_with_shell(RFKILL_STATUS_CMD, function(stdout)
		local is_disabled = stdout:match("no")
		awful.spawn.easy_async_with_shell(
			get_toggle_cmd(is_disabled),
			function()
				awesome.emit_signal("signal::airplane", is_disabled)
			end
		)
	end)
end
