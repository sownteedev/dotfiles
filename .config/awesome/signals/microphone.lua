local awful = require("awful")
local gears = require("gears")

local function mic()
	awful.spawn.easy_async_with_shell(
		"bash -c \"pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\\b\\d+(?=%)' | head -n 1\"",
		function(stdout)
			local mic_int = tonumber(stdout)
			awesome.emit_signal("signal::mic", mic_int)
		end
	)
end

gears.timer({
	timeout = 1,
	call_now = true,
	autostart = true,
	callback = function()
		mic()
	end,
	single_shot = true,
})

local function mic_mute()
	awful.spawn.easy_async_with_shell("bash -c 'pactl get-source-mute @DEFAULT_SOURCE@'", function(value)
		local boolen = value:match("yes")
		awesome.emit_signal("signal::micmute", boolen)
	end)
end

mic_mute()
local subscribe =
	[[ bash -c "LANG=C pactl subscribe 2> /dev/null | grep --line-buffered \"Event 'change' on source\"" ]]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^pactl subscribe" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			mic_mute()
		end,
	})
end)
