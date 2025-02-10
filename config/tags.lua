local awful          = require("awful")
local beautiful      = require("beautiful")

awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.tile,
}

client.connect_signal("request::titlebars", function(c)
	if c.requests_no_titlebar then return end
	require("widgets.titlebar.gtk")(c)
end)

screen.connect_signal("request::desktop_decoration", function(s)
	awful.tag(_User.Tag, s, awful.layout.layouts[1])
	s.bar        = require("widgets.topbar")(s)

	s.dock       = require("widgets.dock")(s)
	s.control    = require("widgets.control")(s)
	s.exit       = require("widgets.exit")(s)
	s.noticenter = require("widgets.noticenter")(s)
	s.lock       = require("widgets.lock")(s)

	s.calendar   = require("widgets.popup.calendar")(s)
	s.image      = require("widgets.popup.image")(s)
	s.music      = require("widgets.popup.music")(s)
	s.system     = require("widgets.popup.system")(s)
	s.weather    = require("widgets.popup.weather")(s)
	s.battery    = require("widgets.popup.battery")(s)
	s.brivol     = require("widgets.popup.brivolmic")(s)
	s.preview    = require("widgets.popup.preview.previewtags")(s)
	s.clock      = require("widgets.popup.clock")(s)
	s.todo       = require("widgets.popup.todo")(s)
	s.launcher   = require("widgets.popup.launcher")
end)

local TAGS_FILE = "/tmp/awesomewm-last-selected-tags"
local function save_selected_tags()
	local success, file = pcall(io.open, TAGS_FILE, "w+")
	if not success or not file then return end

	for s in screen do
		file:write(s.selected_tag.index, "\n")
	end
	file:close()
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
	save_selected_tags()
end)

awesome.connect_signal("startup", function()
	restore_selected_tags()
end)

local tag = require("awful.widget.taglist")
local original_create = tag.taglist_label
tag.taglist_label = function(t, args)
	beautiful.taglist_font = t.selected and _User.Sans .. " Bold 12" or _User.Sans .. " Medium 12"
	local result = original_create(t, args)
	return result
end
