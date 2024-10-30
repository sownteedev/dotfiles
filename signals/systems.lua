local awful = require("awful")

local COMMANDS = {
	cpu = [[sh -c "vmstat 1 2 | tail -1 | awk '{printf \"%d\", $15}'"]],
	ram = [[sh -c "free -m | grep 'Mem:' | awk '{printf \"%d@@%d\", $7, $2}'"]],
	disk = [[sh -c "df -h | grep '/$' | awk '{printf \"%d\", $5}'"]]
}

local INTERVALS = {
	cpu = 10,
	ram = 10,
	disk = 86400,
}

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

awful.widget.watch(COMMANDS.cpu, INTERVALS.cpu, function(_, stdout)
	local cpu_idle = tonumber(trim(stdout)) or 0
	awesome.emit_signal("signal::cpu", 100 - cpu_idle)
end)

awful.widget.watch(COMMANDS.ram, INTERVALS.ram, function(_, stdout)
	local available, total = stdout:match("(%d+)@@(%d+)")
	if available and total then
		available = tonumber(available)
		total = tonumber(total)
		if available and total and total > 0 then
			local used = total - available
			local value = math.floor((used / total) * 100)
			awesome.emit_signal("signal::memory", value)
		end
	end
end)

awful.widget.watch(COMMANDS.disk, INTERVALS.disk, function(_, stdout)
	local value = tonumber(trim(stdout))
	if value then
		awesome.emit_signal("signal::disk", value)
	end
end)
