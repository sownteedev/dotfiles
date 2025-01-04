pcall(require, "luarocks.loader")
require("awful.autofocus")
_User = require("user")
_Utils = require("utils")

---@diagnostic disable: param-type-mismatch
collectgarbage("setpause", 150)
collectgarbage("setstepmul", 500)

local memory_last_check_count = collectgarbage("count")
local memory_last_run_time = os.time()
local memory_growth_factor = 1.1
local memory_long_collection_time = 600

require("gears.timer").start_new(15, function()
	local cur_memory = collectgarbage("count")
	local elapsed = os.time() - memory_last_run_time
	local waited_long = elapsed >= memory_long_collection_time
	local grew_enough = cur_memory > memory_last_check_count * memory_growth_factor
	if grew_enough or waited_long then
		collectgarbage("collect")
		collectgarbage("collect")
		memory_last_run_time = os.time()
	end
	memory_last_check_count = math.max(memory_last_check_count, collectgarbage("count"))
	return true
end)

require("beautiful").init(require("gears").filesystem.get_configuration_dir() .. "themes/theme.lua")
require("config")
require("signals")
