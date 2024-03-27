pcall(require, "luarocks.loader")
require("awful.autofocus")
require("beautiful").init(require("gears").filesystem.get_configuration_dir() .. "themes/theme.lua")

collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
require("gears").timer({
	timeout = 300,
	autostart = true,
	call_now = true,
	callback = function()
		collectgarbage("collect")
	end,
})

require("themes.toggle")
require("config")
require("signals")
require("ui")
