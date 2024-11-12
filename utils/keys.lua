local awful = require("awful")

local keys = {}
keys.open_once = function(client_class, exec_command)
	local matcher = function(c)
		for _, class_value in pairs(client_class) do
			if awful.rules.match(c, { class = class_value }) then
				return true
			end
		end

		return false
	end
	local isOpened = false
	local clients = client.get(mouse.screen)
	for _, c in ipairs(clients) do
		if matcher(c) then
			isOpened = true
			c:emit_signal('request::activate', 'key.unminimize', { raise = true })
		end
	end

	if not isOpened then
		awful.spawn(exec_command)
	end
end

keys.toggle_show_desktop = function()
	local screen = awful.screen.focused()
	local tag = screen.selected_tag
	if tag then
		awful.tag.viewonly(tag)
		for _, c in ipairs(tag:clients()) do
			c.minimized = not c.minimized
		end
	end
end

return keys
