local awful = require("awful")

local function light_emit()
	awful.spawn.easy_async_with_shell("sh -c 'cat ~/.cache/redshift'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::redshift", status)
	end)
end
light_emit()

function redshift_toggle()
	awful.spawn.easy_async_with_shell("sh -c 'cat ~/.cache/redshift'", function(stdout)
		local status = stdout:match("true")
		awful.spawn.with_shell(status and "sh -c 'redshift -x && echo false > ~/.cache/redshift'" or
			"sh -c 'redshift -O 4000 && echo true > ~/.cache/redshift'")
		awesome.emit_signal("signal::redshift", not status)
	end)
end
