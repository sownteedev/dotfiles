local awful = require("awful")

local function blur_emit()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/blur'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::blur", status)
	end)
end
blur_emit()

local subscribe = [[bash -c 'while (inotifywait -e modify ~/.cache/blur -qq) do echo; done']]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^inotifywait" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			blur_emit()
		end,
	})
end)

function blur_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/blur'", function(stdout)
		awful.spawn.easy_async_with_shell("bash -c 'pkill picom'", function()
			local status = stdout:match("true")
			awful.spawn.with_shell(
				status and "bash -c 'picom --config ~/.config/picom/picom_no_opacity.conf -b'" or
				"bash -c 'picom --config ~/.config/picom/picom.conf -b'"
			)
			awful.spawn.with_shell(status and "bash -c 'echo false > ~/.cache/blur'" or
				"bash -c 'echo true > ~/.cache/blur'")
		end)
	end)
end
