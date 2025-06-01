local awful = require("awful")
local gears = require("gears")

for _, cmd in ipairs(_User.AutoStart) do
	awful.spawn.with_shell(cmd)
end
awful.spawn.easy_async_with_shell("cat ~/.cache/awesome/blur", function(stdout)
	local status = stdout:match("true")
	awful.spawn.with_shell(
		not status and "picom --config ~/.config/awesome/scripts/picom/picom_no_opacity -b" or
		"picom --config ~/.config/awesome/scripts/picom/picom.conf -b"
	)
end)

gears.timer.start_new(2, function()
	awful.spawn.with_shell("ibus engine Bamboo")
end)
