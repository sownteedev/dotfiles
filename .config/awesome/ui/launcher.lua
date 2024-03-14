local awful = require("awful")
local wibox = require("wibox")
local Gio = require("lgi").Gio
local iconTheme = require("lgi").require("Gtk", "3.0").IconTheme.get_default()
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")
local L = {}

local Conf = {
	rows = 8,
	entry_height = 100,
	entry_width = 450,
	popup_margins = 15,
}

local createPowerButton = function(icon, color, command)
	return wibox.widget({
		{
			{
				{
					markup = helpers.colorizeText(icon, color),
					align = "center",
					font = beautiful.icon .. " 25",
					widget = wibox.widget.textbox,
				},
				widget = wibox.container.margin,
				left = 30,
				right = 15,
				top = 20,
				bottom = 20,
			},
			widget = wibox.container.background,
			bg = color .. "11",
			shape = helpers.rrect(5),
		},
		widget = wibox.container.place,
		halign = "center",
		buttons = {
			awful.button({}, 1, function()
				L:close()
				awful.spawn.with_shell(command)
			end),
		},
	})
end

local sidebar = wibox.widget({
	widget = wibox.container.background,
	bg = beautiful.background,
	forced_width = Conf.entry_height + 10,
	{
		layout = wibox.layout.align.vertical,
		{
			{
				{
					widget = wibox.widget.imagebox,
					image = beautiful.profile,
					forced_height = 80,
					forced_width = 80,
					resize = true,
				},
				widget = wibox.container.place,
				halign = "center",
			},
			widget = wibox.container.margin,
			top = 15,
		},
		nil,
		{
			{
				createPowerButton(" ", beautiful.blue, "awesome-client \"awesome.emit_signal('toggle::lock')\""),
				createPowerButton(" ", beautiful.yellow, "reboot"),
				createPowerButton("󰐥 ", beautiful.red, "poweroff"),
				spacing = 15,
				layout = wibox.layout.fixed.vertical,
			},
			widget = wibox.container.margin,
			bottom = 15,
		},
	},
})

local prompt = wibox.widget({
	{
		image = helpers.cropSurface(4.5, gears.surface.load_uncached(beautiful.wallpaper)),
		opacity = 1,
		forced_height = 100,
		clip_shape = helpers.rrect(5),
		forced_width = Conf.entry_height,
		widget = wibox.widget.imagebox,
	},
	{
		{
			{
				{
					{
						markup = "",
						forced_height = 10,
						id = "txt",
						font = beautiful.sans .. " 15",
						widget = wibox.widget.textbox,
					},
					{
						markup = "Search...",
						forced_height = 10,
						id = "placeholder",
						font = beautiful.sans .. " 15",
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.stack,
				},
				widget = wibox.container.margin,
				left = 20,
			},
			forced_width = Conf.entry_width - 200,
			forced_height = 60,
			shape = helpers.rrect(5),
			widget = wibox.container.background,
			bg = beautiful.darker .. "50",
		},
		widget = wibox.container.place,
		halign = "center",
		valgn = "center",
	},
	layout = wibox.layout.stack,
})

local entries_container = wibox.widget({
	layout = wibox.layout.grid,
	homogeneous = false,
	expand = true,
	forced_num_cols = 1,
	forced_width = Conf.entry_width,
})

local main_widget = wibox.widget({
	widget = wibox.container.margin,
	margins = 0,
	{
		widget = wibox.container.background,
		forced_height = (Conf.entry_height * (Conf.rows + 1)) + Conf.popup_margins,
		{
			layout = wibox.layout.fixed.horizontal,
			spacing = Conf.popup_margins,
			sidebar,
			{
				{
					layout = wibox.layout.fixed.vertical,
					spacing = Conf.popup_margins,
					prompt,
					entries_container,
				},
				widget = wibox.container.margin,
				left = 0,
				right = Conf.popup_margins,
				bottom = Conf.popup_margins,
				top = Conf.popup_margins,
			},
		},
	},
})

local popup_widget = awful.popup({
	bg = beautiful.darker,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	ontop = true,
	visible = false,
	placement = function(d)
		awful.placement.bottom_left(d, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end,
	maximum_width = Conf.entry_width + Conf.entry_height + Conf.popup_margins * 3,
	shape = helpers.rrect(5),
	widget = main_widget,
})

local index_entry, index_start = 1, 1
local unfiltered, filtered, regfiltered = {}, {}, {}

local function next()
	if index_entry ~= #filtered then
		index_entry = index_entry + 1
		if index_entry > index_start + Conf.rows - 1 then
			index_start = index_start + 1
		end
	else
		index_entry = 1
		index_start = 1
	end
end

local function back()
	if index_entry ~= 1 then
		index_entry = index_entry - 1
		if index_entry < index_start then
			index_start = index_start - 1
		end
	else
		index_entry = #filtered
		index_start = #filtered - Conf.rows + 1
	end
end

local function gen()
	local entries = {}
	for _, entry in ipairs(Gio.AppInfo.get_all()) do
		if entry:should_show() then
			local name = entry:get_name():gsub("&", "&amp;"):gsub("<", "&lt;"):gsub("'", "&#39;")
			local icon = entry:get_icon()
			local path
			if icon then
				path = icon:to_string()
				if not path:find("/") then
					local icon_info = iconTheme:lookup_icon(path, 48, 0)
					local p = icon_info and icon_info:get_filename()
					path = p
				end
			end
			table.insert(entries, { name = name, appinfo = entry, icon = path or "" })
		end
	end
	return entries
end

local function filter(input)
	local clear_input = input:gsub("[%(%)%[%]%%]", "")

	filtered = {}
	regfiltered = {}

	for _, entry in ipairs(unfiltered) do
		if entry.name:lower():sub(1, clear_input:len()) == clear_input:lower() then
			table.insert(filtered, entry)
		elseif entry.name:lower():match(clear_input:lower()) then
			table.insert(regfiltered, entry)
		end
	end

	table.sort(filtered, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	table.sort(regfiltered, function(a, b)
		return a.name:lower() < b.name:lower()
	end)

	for i = 1, #regfiltered do
		filtered[#filtered + 1] = regfiltered[i]
	end

	entries_container:reset()

	for i, entry in ipairs(filtered) do
		local entry_widget = wibox.widget({
			shape = helpers.rrect(5),
			forced_height = Conf.entry_height,
			buttons = {
				awful.button({}, 1, function()
					if index_entry == i then
						entry.appinfo:launch()
						L:close()
					else
						index_entry = i
						filter(input)
					end
				end),
				awful.button({}, 4, function()
					back()
					filter(input)
				end),
				awful.button({}, 5, function()
					next()
					filter(input)
				end),
			},
			widget = wibox.container.background,
			{
				{
					{
						image = entry.icon,
						clip_shape = helpers.rrect(10),
						forced_height = 70,
						forced_width = 70,
						valign = "center",
						widget = wibox.widget.imagebox,
					},
					{
						markup = entry.name,
						id = "name",
						widget = wibox.widget.textbox,
						font = beautiful.sans .. " 15",
					},
					layout = wibox.layout.fixed.horizontal,
					spacing = 20,
				},
				left = 30,
				top = 10,
				bottom = 10,
				widget = wibox.container.margin,
			},
		})

		if index_start <= i and i <= index_start + Conf.rows - 1 then
			entries_container:add(entry_widget)
		end

		if i == index_entry then
			entry_widget.fg = beautiful.foreground
		end

		if i == index_entry then
			entry_widget.bg = beautiful.background
			entry_widget:get_children_by_id("name")[1].markup = helpers.colorizeText(entry.name, beautiful.blue)
		end
	end

	if index_entry > #filtered then
		index_entry, index_start = 1, 1
	elseif index_entry < 1 then
		index_entry = 1
	end

	collectgarbage("collect")
end

local exclude = {
	"Shift_R",
	"Shift_L",
	"Super_R",
	"Super_L",
	"Tab",
	"Alt_R",
	"Alt_L",
	"Control_L",
	"Control_R",
	"Caps_Lock",
	"Print",
	"Insert",
	"CapsLock",
	"Home",
	"End",
	"Down",
	"Up",
	"Left",
	"Right",
}
local function has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

local prompt_grabber = awful.keygrabber({
	auto_start = true,
	stop_event = "release",
	keypressed_callback = function(self, mod, key, command)
		local addition = ""
		if key == "Escape" then
			L:close()
		elseif key == "BackSpace" then
			prompt:get_children_by_id("txt")[1].markup = prompt:get_children_by_id("txt")[1].markup:sub(1, -2)
			filter(prompt:get_children_by_id("txt")[1].markup)
		elseif key == "Delete" then
			prompt:get_children_by_id("txt")[1].markup = ""
			filter(prompt:get_children_by_id("txt")[1].markup)
		elseif key == "Return" then
			local entry = filtered[index_entry]
			if entry then
				entry.appinfo:launch()
			else
				awful.spawn.with_shell(prompt:get_children_by_id("txt")[1].markup)
			end
			L:close()
		elseif key == "Up" then
			back()
		elseif key == "Down" then
			next()
		elseif has_value(exclude, key) then
			addition = ""
		else
			addition = key
		end
		prompt:get_children_by_id("txt")[1].markup = prompt:get_children_by_id("txt")[1].markup .. addition
		filter(prompt:get_children_by_id("txt")[1].markup)
		if string.len(prompt:get_children_by_id("txt")[1].markup) > 0 then
			prompt:get_children_by_id("placeholder")[1].markup = ""
		else
			prompt:get_children_by_id("placeholder")[1].markup = "Search..."
		end
	end,
})

function L:open()
	popup_widget.visible = true
	unfiltered = gen()
	filter("")
	prompt_grabber:start()
end

function L:close()
	popup_widget.visible = false
	prompt_grabber:stop()
	prompt:get_children_by_id("txt")[1].markup = ""
end

function L:toggle()
	if not popup_widget.visible then
		self:open()
	else
		self:close()
	end
end

return L
