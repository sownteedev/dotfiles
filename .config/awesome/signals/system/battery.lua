local awful           = require("awful")
local gears           = require('gears')

local update_interval = 60
local bat_script      = [[
	sh -c "cat /sys/class/power_supply/BAT*/capacity"
]]
local bat_script_1    = [[
	sh -c "cut -d '=' -f2 /sys/class/power_supply/BAT*/uevent | head -n 3 | tail -n 1"
]]

awful.widget.watch(bat_script, update_interval, function(widget, stdout)
	local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	value = tonumber(value)
	awesome.emit_signal("bat::value", value)
end)

awful.widget.watch(bat_script_1, update_interval, function(widget, stdout)
	local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	awesome.emit_signal("bat::state", value)
end)

local battery_script =
"bash -c 'echo $(cat /sys/class/power_supply/BAT0/capacity) echo $(cat /sys/class/power_supply/BAT0/status)'"

local function battery_emit()
	awful.spawn.easy_async_with_shell(
		battery_script, function(stdout)
			local level     = string.match(stdout:match('(%d+)'), '(%d+)')
			local level_int = tonumber(level)
			local power     = not stdout:match('Discharging')
			awesome.emit_signal('signal::battery', level_int, power)
		end)
end

gears.timer {
	timeout   = 60,
	call_now  = true,
	autostart = true,
	callback  = function()
		battery_emit()
	end
}
