local awful = require("awful")

local BLUR_CACHE = os.getenv("HOME") .. "/.cache/awesome/blur"
local PICOM_NORMAL = os.getenv("HOME") .. "/.config/picom/picom.conf"
local PICOM_NO_OPACITY = os.getenv("HOME") .. "/.config/picom/picom_no_opacity.conf"

local function get_picom_cmd(config)
	return string.format("picom --config %s -b", config)
end

local function get_blur_state_cmd(state)
	return string.format("echo %s > %s", state and "true" or "false", BLUR_CACHE)
end

local function blur_emit()
	awful.spawn.easy_async_with_shell("cat " .. BLUR_CACHE, function(stdout)
		awesome.emit_signal("signal::blur", stdout:match("true"))
	end)
end

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

blur_emit()
