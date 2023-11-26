local awful = require("awful")

-- DISK
local update_interval = 600
local disk_script = [[
	sh -c "df -h /home |grep '^/' | awk '{print $5}' | tr -d '%'"
]]

awful.widget.watch(disk_script, update_interval, function(widget, stdout)
	local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	awesome.emit_signal("disk::value", value)
end)

-- CPU
local update_interval = 4
local cpu_idle_script = [[
	sh -c "
	vmstat 1 2 | tail -1 | awk '{printf \"%d\", $15}'
	"]]

awful.widget.watch(cpu_idle_script, update_interval, function(widget, stdout)
	local cpu_idle = stdout
	cpu_idle = string.gsub(cpu_idle, '^%s*(.-)%s*$', '%1')
	awesome.emit_signal("signal::cpu", 100 - tonumber(cpu_idle))
end)

-- RAM
local update_interval = 20
local ram_script = [[
	sh -c "
	free -m | grep 'Mem:' | awk '{printf \"%d@@%d@\", $7, $2}'
	"]]

awful.widget.watch(ram_script, update_interval, function(widget, stdout)
	local available = stdout:match('(.*)@@')
	local total = stdout:match('@@(.*)@')
	local used = tonumber(total) - tonumber(available)
	local value = math.floor((used / total) * 100)
	awesome.emit_signal("signal::ram", value)
end)
