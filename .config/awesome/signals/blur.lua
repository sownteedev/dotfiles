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
		awful.spawn.easy_async_with_shell("pkill picom", function()
			awful.spawn.with_shell("while pgrep -u $UID -x picom >/dev/null; do sleep 0; done")
			local status = stdout:match("true")
			if status then
				awful.spawn.with_shell(
					"picom --config ~/.config/awesome/signals/scripts/Picom/picom_no_opacity.conf -b &"
				)
				awful.spawn.with_shell("echo false > ~/.cache/blur")
			else
				awful.spawn.with_shell("picom --config ~/.config/awesome/signals/scripts/Picom/picom.conf -b &")
				awful.spawn.with_shell("echo true > ~/.cache/blur")
			end
		end)
	end)
end
