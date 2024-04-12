local awful = require("awful")

local function light_emit()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/redshift'", function(stdout)
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
