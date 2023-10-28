local awful = require("awful")

local update_interval = 600
local disk_script = [[
	sh -c "df -h /home |grep '^/' | awk '{print $5}' | tr -d '%'"
]]

awful.widget.watch(disk_script, update_interval, function(widget, stdout)
	local value =  string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	awesome.emit_signal("disk::value", value)
end)
