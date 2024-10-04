local awful = require("awful")

local function blur_emit()
	awful.spawn.easy_async_with_shell("sh -c 'cat ~/.cache/blur'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::blur", status)
	end)
end
blur_emit()

function blur_toggle()
	awful.spawn.easy_async_with_shell("sh -c 'cat ~/.cache/blur'", function(stdout)
		awful.spawn.easy_async_with_shell("sh -c 'pkill picom'", function()
			local status = stdout:match("true")
			awesome.emit_signal("signal::blur", not status)
			awful.spawn(
				status and "sh -c 'picom --config ~/.config/picom/picom_no_opacity.conf -b'" or
				"sh -c 'picom --config ~/.config/picom/picom.conf -b'"
			)
			awful.spawn(status and "sh -c 'echo false > ~/.cache/blur'" or
				"sh -c 'echo true > ~/.cache/blur'")
		end)
	end)
end
