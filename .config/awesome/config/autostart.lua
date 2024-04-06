local awful = require("awful")
local beautiful = require("beautiful")

awful.spawn.easy_async_with_shell("xrdb -merge ~/.Xresources &")
awful.spawn.easy_async_with_shell("picom --config ~/.config/awesome/signals/scripts/Picom/picom_no_opacity.conf &")
awful.spawn.easy_async_with_shell("feh -z --no-fehbg --bg-fill " .. beautiful.wallpaper .. " &")
awful.spawn.easy_async_with_shell("xss-lock awesome-client 'awesome.emit_signal(\"toggle::lock\")' &")
