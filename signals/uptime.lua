local awful = require("awful")
local gears = require("gears")

local last_pid = nil
local last_uptime = nil

local function kill_last_process()
	if last_pid then
		awful.spawn.easy_async("sh -c 'kill " .. last_pid .. " 2>/dev/null'", function()
			last_pid = nil
		end)
	end
end

local function emit_uptime_status()
	kill_last_process()

	awful.spawn.easy_async_with_shell([[
        sh -c '
        echo $$ > /tmp/uptime_status_pid
        uptime --pretty | sed "s/up\s*//g"
        rm -f /tmp/uptime_status_pid
        ']], function(stdout)
		awful.spawn.easy_async("cat /tmp/uptime_status_pid", function(pid)
			last_pid = pid:gsub("%s+", "")
		end)

		if stdout ~= last_uptime then
			awesome.emit_signal("signal::uptime", stdout)
			last_uptime = stdout
		end
	end)
end

local update_timer = gears.timer({
	timeout = 60,
	autostart = false,
	callback = emit_uptime_status
})

awesome.connect_signal("exit", function()
	kill_last_process()
	update_timer:stop()
end)

update_timer:start()
emit_uptime_status()
