local awful = require("awful")
local gears = require("gears")

local DND_CACHE = gears.filesystem.get_cache_dir() .. "dnd"
local NAUGHTY_TOGGLE = "awesome-client 'naughty = require(\"naughty\") naughty.toggle()'"

local function get_dnd_state_cmd(state)
	return string.format("echo %s > %s", state and "true" or "false", DND_CACHE)
end

awful.spawn.easy_async_with_shell("cat " .. DND_CACHE, function(stdout)
	awesome.emit_signal("signal::dnd", stdout:match("true"))
end)

function dnd_toggle()
	awful.spawn.easy_async_with_shell("cat " .. DND_CACHE, function(stdout)
		local current_status = stdout:match("true")
		local new_status = not current_status

		local commands = table.concat({
			NAUGHTY_TOGGLE,
			get_dnd_state_cmd(new_status)
		}, " && ")

		awful.spawn.easy_async_with_shell(commands, function()
			awesome.emit_signal("signal::dnd", new_status)
		end)
	end)
end
