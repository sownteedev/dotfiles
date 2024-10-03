local awful = require("awful")

local function emit_dnd_status()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/dnd'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::dnd", status)
	end)
end
emit_dnd_status()

function dnd_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/dnd'", function(stdout)
		local status = stdout:match("true")
		awful.spawn.with_shell("awesome-client 'naughty = require(\"naughty\") naughty.toggle()'")
		awful.spawn.with_shell(status and "bash -c 'echo false > ~/.cache/dnd'" or
			"bash -c 'echo true > ~/.cache/dnd'")
		awesome.emit_signal("signal::dnd", not status)
	end)
end
