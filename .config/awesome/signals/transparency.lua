local awful = require("awful")

local function trans_emit()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/transparency'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::transparency", status)
	end)
end

trans_emit()
local subscribe = [[bash -c 'while (inotifywait -e modify ~/.cache/transparency -qq) do echo; done']]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^inotifywait" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			trans_emit()
		end,
	})
end)
