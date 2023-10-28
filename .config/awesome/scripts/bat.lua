local awful = require("awful")

local update_interval = 60
local bat_script = [[
	sh -c "cat /sys/class/power_supply/BAT*/capacity"
]]
local bat_script_1 = [[
	sh -c "cut -d '=' -f2 /sys/class/power_supply/BAT*/uevent | head -n 3 | tail -n 1"
]]

awful.widget.watch(bat_script, update_interval, function(widget, stdout)
	local value =  string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	value = tonumber(value)
	awesome.emit_signal("bat::value", value)
end)

awful.widget.watch(bat_script_1, update_interval, function(widget, stdout)
	local value =  string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	awesome.emit_signal("bat::state", value)
end)


