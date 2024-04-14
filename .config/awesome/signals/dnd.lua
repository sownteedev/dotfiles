local awful = require("awful")
local naughty = require("naughty")

local function emit_dnd_status()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/dnd'", function(stdout)
		local status = stdout:match("true")
		awesome.emit_signal("signal::dnd", status)
	end)
end

emit_dnd_status()
local subscribe = [[bash -c 'while (inotifywait -e modify ~/.cache/dnd -qq) do echo; done']]
awful.spawn.easy_async({ "pkill", "--full", "--uid", os.getenv("USER"), "^inotifywait" }, function()
	awful.spawn.with_line_callback(subscribe, {
		stdout = function()
			emit_dnd_status()
		end,
	})
end)

function dnd_toggle()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/dnd'", function(status)
		status = status:gsub("\n", "")
		if status == "true" then
			awful.spawn.with_shell("awesome-client 'naughty = require(\"naughty\") naughty.toggle()' &")
			awful.spawn.with_shell("bash -c 'echo false > ~/.cache/dnd'")
		else
			awful.spawn.with_shell("awesome-client 'naughty = require(\"naughty\") naughty.toggle()' &")
			awful.spawn.with_shell("bash -c 'echo true > ~/.cache/dnd'")
		end
	end)
end
