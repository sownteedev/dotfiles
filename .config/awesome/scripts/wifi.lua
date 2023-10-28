local awful = require("awful")

function update_value_of_wifi()
	awful.spawn.easy_async_with_shell("nmcli radio wifi", function(stdout)
	local value =  string.gsub(stdout, '^%s*(.-)%s*$', '%1')
	awesome.emit_signal("wifi::value", value)
	end)
end

update_value_of_wifi()
