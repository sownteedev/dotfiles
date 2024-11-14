local awful = require("awful")

local AIRPLANE_CACHE = os.getenv("HOME") .. "/.cache/awesome/airplane"
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

local function airplane_emit()
	awful.spawn.easy_async_with_shell(AIRPLANE_STATUS_CMD, function(stdout)
		awesome.emit_signal("signal::airplane", stdout == "true\n")
	end)
end

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

airplane_emit()
