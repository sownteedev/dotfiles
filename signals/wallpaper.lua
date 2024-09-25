local awful = require("awful")
local config_file = os.getenv("HOME") .. "/.config/awesome/user.lua"

function changewall(path)
	local command = "sed -i 's|_User.Wallpaper       = .*|_User.Wallpaper       = \"" ..
		path .. "\"|' " .. config_file
	awful.spawn.easy_async_with_shell(command, function()
		_User.Wallpaper = path
		awesome.emit_signal("wallpaper::change")
	end)
end

function changelockwall(path)
	local command = "sed -i 's|_User.Lock            = .*|_User.Lock            = \"" .. path .. "\"|' " .. config_file
	awful.spawn.easy_async_with_shell(command, function()
		_User.Lock = path
		awesome.emit_signal("lock::change")
	end)
end
