local awful = require("awful")
local gears = require("gears")

local REDSHIFT_CACHE = gears.filesystem.get_cache_dir() .. "redshift"
local REDSHIFT_RESET = "redshift -x"
local REDSHIFT_ENABLE = "redshift -O 4000"

local function get_redshift_state_cmd(state)
	return string.format("echo %s > %s", state and "true" or "false", REDSHIFT_CACHE)
end

local function get_redshift_cmd(enable)
	return table.concat({
		enable and REDSHIFT_ENABLE or REDSHIFT_RESET,
		get_redshift_state_cmd(enable)
	}, " && ")
end

awful.spawn.easy_async_with_shell("cat " .. REDSHIFT_CACHE, function(stdout)
	awesome.emit_signal("signal::redshift", stdout:match("true"))
end)

function redshift_toggle()
	awful.spawn.easy_async_with_shell("cat " .. REDSHIFT_CACHE, function(stdout)
		local current_status = stdout:match("true")
		local new_status = not current_status

		awful.spawn.easy_async_with_shell(
			get_redshift_cmd(new_status),
			function()
				awesome.emit_signal("signal::redshift", new_status)
			end
		)
	end)
end
