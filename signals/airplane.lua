local awful = require("awful")

local function airplane_emit()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/airplane'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::airplane", status)
	end)
end
airplane_emit()

function airplane_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'rfkill list | sed -n 5p'", function(stdout)
		local status = stdout:match("no")
		awful.spawn.with_shell(status and "bash -c 'rfkill block all && echo true > ~/.cache/airplane'" or
			"bash -c 'rfkill unblock all && echo false > ~/.cache/airplane' &")
		awesome.emit_signal("signal::airplane", status)
	end)
end
