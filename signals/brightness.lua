local awful = require("awful")

local BRIGHTNESS_CACHE = os.getenv("HOME") .. "/.cache/awesome/brightness"
local BACKLIGHT_PATH = "/sys/class/backlight/*"
local BRIGHTNESS_CMD = string.format(
	"echo $(($(cat %s/brightness) * 100 / $(cat %s/max_brightness)))",
	BACKLIGHT_PATH, BACKLIGHT_PATH
)

local function get_brightness_cmd(level, state)
	return string.format(
		"brightnessctl s %d%% && echo %s > %s",
		level,
		state and "true" or "false",
		BRIGHTNESS_CACHE
	)
end

function brightness_emit()
	awful.spawn.easy_async_with_shell(BRIGHTNESS_CMD, function(stdout)
		local value = tonumber(stdout)
		if value then
			awesome.emit_signal("signal::brightness", value)
		end
	end)
end

local function brightnesss()
	awful.spawn.easy_async_with_shell("cat " .. BRIGHTNESS_CACHE, function(stdout)
		awesome.emit_signal("signal::brightnesss", stdout:match("true"))
	end)
end

function brightness_toggle()
	awful.spawn.easy_async_with_shell("brightnessctl i | grep Current", function(stdout)
		local is_dim = stdout:match("25")
		local new_level = is_dim and 75 or 25
		awful.spawn.easy_async_with_shell(
			get_brightness_cmd(new_level, not is_dim),
			function()
				awesome.emit_signal("signal::brightness", new_level)
				awesome.emit_signal("signal::brightnesss", not is_dim)
			end
		)
	end)
end

brightness_emit()
brightnesss()
