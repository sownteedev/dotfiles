local awful = require("awful")

awful.spawn.with_shell("xrdb -merge ~/.Xresources &")
awful.spawn.with_shell("~/.config/awesome/signals/scripts/Picom/toggle --no-opacity &")
awful.spawn.with_shell("feh -z --no-fehbg --bg-fill ~/.walls &")
awful.spawn.with_shell("xss-lock awesome-client 'awesome.emit_signal(\"toggle::lock\")' &")
