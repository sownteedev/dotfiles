local awful          = require("awful")
local gears          = require("gears")
local beautiful      = require("beautiful")
local helpers        = require("helpers")

awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.tile,
}

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
	s.preview = require("widgets.popup.previewtags")(s)
end)

gears.wallpaper.maximized(_User.Wallpaper, nil, true)
awesome.connect_signal("wallpaper::change", function()
	gears.wallpaper.maximized(_User.Wallpaper, nil, true)
end)

local CACHE_DIR = gears.filesystem.get_cache_dir()
local TAGS_FILE = "/tmp/awesomewm-last-selected-tags"
local window_positions = helpers.readJson(CACHE_DIR .. "window_positions.json")

local function save_window_positions()
	for _, c in ipairs(client.get()) do
		if c.class and not c.maximized then
			local geometry = c:geometry()
			window_positions[c.class] = {
				x = geometry.x,
				y = geometry.y,
				width = c.class == "Alacritty" and geometry.width or nil,
				height = c.class == "Alacritty" and geometry.height or nil
			}
		end
	end
	helpers.writeJson(CACHE_DIR .. "window_positions.json", window_positions)
end

local function save_selected_tags()
	local success, file = pcall(io.open, TAGS_FILE, "w+")
	if not success or not file then return end

	for s in screen do
		file:write(s.selected_tag.index, "\n")
	end
	file:close()
end

local function restore_window_positions()
	for _, c in ipairs(client.get()) do
		if c.class and window_positions[c.class] then
			c:geometry(window_positions[c.class])
		end
	end
end

local function restore_selected_tags()
	local success, file = pcall(io.open, TAGS_FILE, "r")
	if not success or not file then return end

	local selected_tags = {}
	for line in file:lines() do
		table.insert(selected_tags, tonumber(line))
	end

	for s in screen do
		local tag = s.tags[selected_tags[s.index]]
		if tag then
			tag:view_only()
		end
	end
	file:close()
end

awesome.connect_signal("exit", function(reason_restart)
	if not reason_restart then return end

	save_window_positions()
	save_selected_tags()
end)

awesome.connect_signal("startup", function()
	restore_window_positions()
	restore_selected_tags()
end)

local tag = require("awful.widget.taglist")
local original_create = tag.taglist_label
tag.taglist_label = function(t, args)
	beautiful.taglist_font = t.selected and _User.Sans .. " Bold 12" or _User.Sans .. " Medium 12"
	local result = original_create(t, args)
	return result
end
