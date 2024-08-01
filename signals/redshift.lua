local awful = require("awful")

local function light_emit()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/redshift' &", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::redshift", status)
	end)
end
light_emit()

local subscribe = [[bash -c 'while (inotifywait -e modify ~/.cache/redshift -qq) do echo; done']]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^inotifywait" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			light_emit()
		end,
	})
end)

function redshift_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/redshift' &", function(status)
		status = status:gsub("\n", "")
		awful.spawn.with_shell(status == "true" and "bash -c 'redshift -x && echo false > ~/.cache/redshift' &" or
			"bash -c 'redshift -O 4000 && echo true > ~/.cache/redshift' &")
	end)
end
