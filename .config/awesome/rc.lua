pcall(require, "luarocks.loader")
require("awful.autofocus")
require("beautiful").init(require("gears").filesystem.get_configuration_dir() .. "themes/theme.lua")
require("config")
require("signals")
require("widgets")

require("gears").timer({
	timeout = 5,
	autostart = true,
	call_now = true,
	callback = function()
		collectgarbage("collect")
	end,
})

---@diagnostic disable: param-type-mismatch
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)

awesome.emit_signal("live::reload")
