local awful = require("awful")

local function airplane_emit()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/airplane'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::airplane", status)
	end)
end
airplane_emit()

local subscribe = [[bash -c 'while (inotifywait -e modify ~/.cache/airplane -qq) do echo; done']]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^inotifywait" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			airplane_emit()
		end,
	})
end)

function airplane_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'rfkill list | sed -n 5p'", function(status)
		status = status:match("no")
		awful.spawn.with_shell(status and "bash -c 'rfkill block all && echo true > ~/.cache/airplane'" or
		"bash -c 'rfkill unblock all && echo false > ~/.cache/airplane'")
	end)
end
