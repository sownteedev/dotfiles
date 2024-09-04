pcall(require, "luarocks.loader")
require("awful.autofocus")

local naughty = require('naughty')
naughty.connect_signal('request::display_error', function(message, startup)
	naughty.notification({
		urgency = 'critical',
		title   = 'Oops, an error happened' .. (startup and ' during startup!' or '!'),
		message = message
	})
end)

require("beautiful").init(require("gears").filesystem.get_configuration_dir() .. "themes/theme.lua")
require("config")
require("signals")

collectgarbage("incremental", 110, 1000)
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)

local memory_last_check_count = collectgarbage("count")
local memory_last_run_time = os.time()
local memory_growth_factor = 1.1
local memory_long_collection_time = 300

require("gears.timer").start_new(5, function()
	local cur_memory = collectgarbage("count")
	local elapsed = os.time() - memory_last_run_time
	local waited_long = elapsed >= memory_long_collection_time
	local grew_enough = cur_memory > (memory_last_check_count * memory_growth_factor)
	if grew_enough or waited_long then
		collectgarbage("collect")
		collectgarbage("collect")
		memory_last_run_time = os.time()
	end
	memory_last_check_count = collectgarbage("count")
	return true
end)
