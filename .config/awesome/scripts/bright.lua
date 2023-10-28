local awful = require("awful")

local icon = ""

function update_value_of_bright()
	awful.spawn.easy_async_with_shell("brightnessctl i | grep Current | awk '{print $4}' | tr -d '()%'", function (stdout)
		local value = string.gsub(stdout, '^%s*(.-)%s*$', '%1')
		value = tonumber(value)
		awesome.emit_signal("bright::value", value, icon)
	end)
end

update_value_of_bright()

