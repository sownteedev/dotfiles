local awful = require("awful")

-- awful.spawn.easy_async_with_shell("xrandr --auto --output DP-1 --mode 3840x2160 --primary --auto --right-of eDP-1 &")
awful.spawn.easy_async_with_shell("xss-lock -l awesome-client 'awesome.emit_signal(\"toggle::lock\")' &")
awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/blur' &", function(stdout)
	local status = stdout:match("true")
	awful.spawn.easy_async_with_shell(
		not status and "bash -c 'picom --config ~/.config/awesome/signals/scripts/Picom/picom_no_opacity.conf -b' &" or
		"bash -c 'picom --config ~/.config/awesome/signals/scripts/Picom/picom.conf -b' &"
	)
end)
