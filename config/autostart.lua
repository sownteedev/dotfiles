local awful = require("awful")

-- awful.spawn.with_shell("xrandr --auto --output DP-1 --mode 3840x2160 --primary --auto --right-of eDP-1 &")
awful.spawn.with_shell("xss-lock -l awesome-client 'awesome.emit_signal(\"toggle::lock\")'")
awful.spawn.with_shell("libinput-gestures-setup start")
awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/blur'", function(stdout)
	local status = stdout:match("true")
	awful.spawn.with_shell(
		not status and "bash -c 'picom --config ~/.config/picom/picom_no_opacity.conf -b'" or
		"bash -c 'picom --config ~/.config/picom/picom.conf -b'"
	)
end)
