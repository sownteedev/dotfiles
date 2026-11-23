local awful = require("awful")
local gears = require("gears")

gears.filesystem.make_directories(gears.filesystem.get_cache_dir())

for _, cmd in ipairs(_User.AutoStart) do
	awful.spawn.with_shell(cmd)
end

awful.spawn({ gears.filesystem.get_configuration_dir() .. "scripts/picom.sh", "start" })
