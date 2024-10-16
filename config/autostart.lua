local awful = require("awful")
local gears = require("gears")

for _, cmd in ipairs(_User.AutoStart) do
	awful.spawn.with_shell(cmd)
end
awful.spawn.easy_async_with_shell("sh -c 'cat ~/.cache/blur'", function(stdout)
	local status = stdout:match("true")
	awful.spawn.with_shell(
		not status and "sh -c 'picom --config ~/.config/picom/picom_no_opacity.conf -b'" or
		"sh -c 'picom --config ~/.config/picom/picom.conf -b'"
	)
end)

gears.timer.start_new(2, function()
	awful.spawn.with_shell("ibus engine Bamboo")
end)
