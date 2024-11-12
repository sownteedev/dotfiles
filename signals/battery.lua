local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")

local charging = false

local function battery_emit()
	awful.spawn.easy_async_with_shell("sh -c 'cat /sys/class/power_supply/BAT0/capacity'",
		function(stdout)
			local level = tonumber(string.match(stdout:match("(%d+)"), "(%d+)"))
			awesome.emit_signal("signal::battery", level)
		end
	)
end
battery_emit()

local last_status = nil
local function battery_status()
	awful.spawn.easy_async_with_shell("sh -c 'cat /sys/class/power_supply/BAT0/status'",
		function(stdout)
			local status = not stdout:match("Discharging")
			charging = status
			if status ~= last_status then
				awesome.emit_signal("signal::batterystatus", status)
				last_status = status
			end
		end
	)
end
battery_status()

local battery = _Utils.upower.gobject_to_gearsobject(_Utils.upower.upowers:get_display_device())
battery:connect_signal("property::percentage", battery_emit)
battery:connect_signal("property::state", battery_status)

local last_notification = nil
awesome.connect_signal("signal::battery", function(level)
	if (level == 20 or level == 10) and last_notification ~= level and not charging then
		last_notification = level
		naughty.notify({
			app_name = "default",
			icon = beautiful.icon_path .. "awm/battery-low.svg",
			title = _Utils.widget.colorizeText("Low Battery", beautiful.red),
			text = "Your battery percentage is lower than " ..
				level .. "%. Please connect your Laptop to the charger!",
		})
	end
end)

local first_run_status = true
awesome.connect_signal("signal::batterystatus", function(status)
	if not first_run_status then
		local stt = status and "Your laptop has just been plugged in!" or "The laptop charger has just been unplugged!"
		naughty.notify({
			app_name = "battery",
			title = _Utils.widget.colorizeText("Battery Status", beautiful.yellow),
			text = stt,
		})
	else
		first_run_status = false
	end
end)
