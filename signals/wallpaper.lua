local awful = require("awful")
local beautiful = require("beautiful")

function changewall(path, type)
	local config_file = os.getenv("HOME") .. "/.config/awesome/themes/colors/" .. type .. ".lua"
	local command = "sed -i 's|wallpaper = .*|wallpaper = \"" .. path .. "\",|' " .. config_file
	awful.spawn.easy_async_with_shell(command, function()
		beautiful.wallpaper = path
		awesome.emit_signal("wallpaper::change")
	end)
end

function changelockwall(path)
	local config_file = os.getenv("HOME") .. "/.config/awesome/user.lua"
	local command = "sed -i 's|_User.LOCK            = .*|_User.LOCK            = \"" .. path .. "\"|' " .. config_file
	awful.spawn.easy_async_with_shell(command, function()
		_User.LOCK = path
		awesome.emit_signal("lock::change")
	end)
end
