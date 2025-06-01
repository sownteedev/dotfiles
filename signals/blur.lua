local awful = require("awful")
local gears = require("gears")

local BLUR_CACHE = gears.filesystem.get_cache_dir() .. "blur"
local PICOM_NORMAL = gears.filesystem.get_configuration_dir() .. "scripts/picom/picom.conf"
local PICOM_NO_OPACITY = gears.filesystem.get_configuration_dir() .. "scripts/picom/picom_no_opacity.conf"

local function get_picom_cmd(config)
	return string.format("picom --config %s -b", config)
end

local function get_blur_state_cmd(state)
	return string.format("echo %s > %s", state and "true" or "false", BLUR_CACHE)
end

awful.spawn.easy_async_with_shell("cat " .. BLUR_CACHE, function(stdout)
	awesome.emit_signal("signal::blur", stdout:match("true"))
end)

function blur_toggle()
	awful.spawn.easy_async_with_shell("cat " .. BLUR_CACHE, function(stdout)
		local current_status = stdout:match("true")
		local new_status = not current_status
		local commands = table.concat({
			"pkill picom",
			get_picom_cmd(current_status and PICOM_NO_OPACITY or PICOM_NORMAL),
			get_blur_state_cmd(new_status)
		}, " && ")
		awful.spawn.easy_async_with_shell(commands, function()
			awesome.emit_signal("signal::blur", new_status)
		end)
	end)
end
