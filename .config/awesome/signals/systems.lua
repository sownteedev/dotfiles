local awful = require("awful")

-- CPU
local update_interval_cpu = 2
local cpu_script = [[bash -c "vmstat 1 2 | tail -1 | awk '{printf \"%d\", $15}'"]]
awful.widget.watch(cpu_script, update_interval_cpu, function(widget, stdout)
	local cpu_idle = stdout
	cpu_idle = string.gsub(cpu_idle, "^%s*(.-)%s*$", "%1")
	awesome.emit_signal("signal::cpu", 100 - tonumber(cpu_idle))
end)

-- RAM
local update_interval_ram = 2
local ram_script = [[bash -c "free -m | grep 'Mem:' | awk '{printf \"%d@@%d@\", $7, $2}'"]]
awful.widget.watch(ram_script, update_interval_ram, function(widget, stdout)
	local available = stdout:match("(.*)@@")
	local total = stdout:match("@@(.*)@")
	local used = tonumber(total) - tonumber(available)
	local value = math.floor((used / total) * 100)
	awesome.emit_signal("signal::memory", value)
end)

-- DISK
local update_interval_disk = 86400
local disk_script = [[bash -c "df -h | grep '/$' | awk '{printf \"%d\", $5}'"]]
awful.widget.watch(disk_script, update_interval_disk, function(widget, stdout)
	local value = stdout
	value = string.gsub(value, "^%s*(.-)%s*$", "%1")
	awesome.emit_signal("signal::disk", tonumber(value))
end)
