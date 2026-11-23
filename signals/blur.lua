local awful = require("awful")
local gears = require("gears")

local BLUR_CACHE = gears.filesystem.get_cache_dir() .. "blur"
local PICOM_SCRIPT = gears.filesystem.get_configuration_dir() .. "scripts/picom.sh"

awful.spawn.easy_async_with_shell("cat " .. BLUR_CACHE, function(stdout)
	awesome.emit_signal("signal::blur", stdout:match("true"))
end)

function blur_toggle()
	awful.spawn.easy_async({ PICOM_SCRIPT, "toggle" }, function(_, _, _, code)
		if code ~= 0 then return end
		awful.spawn.easy_async({ "cat", BLUR_CACHE }, function(stdout)
			awesome.emit_signal("signal::blur", stdout:match("true") ~= nil)
		end)
	end)
end
