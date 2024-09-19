local awful          = require("awful")
local gears          = require("gears")
local beautiful      = require("beautiful")
local helpers        = require("helpers")

awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.tile,
}

client.connect_signal("request::manage", function(c)
	if not awesome.startup then awful.client.setslave(c) end
	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		awful.placement.no_offscreen(c)
	end
end)

client.connect_signal("request::titlebars", function(c)
	if c.requests_no_titlebar then return end
	require("widgets.titlebar")(c)
end)

screen.connect_signal("request::desktop_decoration", function(s)
	awful.tag({ "Terminal", "Browser", "Develop", "Media", "Other" }, s, awful.layout.layouts[1])
	s.bar = require("widgets.topbar")(s)

	s.dock = require("widgets.dock")(s)
	s.control = require("widgets.control")(s)
	s.exit = require("widgets.exit")(s)
	s.noticenter = require("widgets.noticenter")(s)
	s.lock = require("widgets.lock")(s)

	s.calendar = require("widgets.popup.calendar")(s)
	s.image = require("widgets.popup.image")(s)
	s.music = require("widgets.popup.music")(s)
	s.system = require("widgets.popup.system")(s)
	s.weather = require("widgets.popup.weather")(s)
	s.battery = require("widgets.popup.battery")(s)
	s.brivol = require("widgets.popup.brivolmic")(s)
	s.preview = require("widgets.popup.preview")(s)
end)

gears.wallpaper.maximized(beautiful.wallpaper)

---@diagnostic disable: need-check-nil
awesome.connect_signal("exit", function(reason_restart)
	if not reason_restart then
		return
	end

	local window_positions = helpers.readJson(gears.filesystem.get_cache_dir() .. "window_positions.json")
	for _, c in ipairs(client.get()) do
		if c.class then
			window_positions[c.class] = {
				x = c:geometry().x,
				y = c:geometry().y,
				width = c:geometry().width,
				height = c:geometry().height
			}
		end
	end
	helpers.writeJson(gears.filesystem.get_cache_dir() .. "window_positions.json", window_positions)

	local file = io.open("/tmp/awesomewm-last-selected-tags", "w+")
	for s in screen do
		file:write(s.selected_tag.index, "\n")
	end
	file:close()
end)

awesome.connect_signal("startup", function()
	local window_positions = helpers.readJson(gears.filesystem.get_cache_dir() .. "window_positions.json")
	for _, c in ipairs(client.get()) do
		if c.class and window_positions[c.class] then
			local geo = window_positions[c.class]
			c:geometry({
				x = geo.x,
				y = geo.y,
				width = geo.width,
				height = geo.height
			})
		end
	end

	local file = io.open("/tmp/awesomewm-last-selected-tags", "r")
	if file then
		local selected_tags = {}
		for line in file:lines() do
			table.insert(selected_tags, tonumber(line))
		end
		for s in screen do
			local i = selected_tags[s.index]
			local t = s.tags[i]
			if t then
				t:view_only()
			end
		end
		file:close()
	end
end)

local tag = require("awful.widget.taglist")
local original_create = tag.taglist_label
tag.taglist_label = function(t, args)
	beautiful.taglist_font = t.selected and "SF Pro Display Bold 12" or "SF Pro Display Medium 12"
	local result = original_create(t, args)
	return result
end
