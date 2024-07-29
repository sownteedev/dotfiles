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
	entry_height = 80,
	entry_width = 450,
	popup_margins = 15,
}

local createPowerButton = function(path, color, command)
	local buttons = wibox.widget({
		{
			{
				{
					id = "icon",
					image = path,
					resize = true,
					forced_height = 30,
					forced_width = 30,
					halign = "center",
					widget = wibox.widget.imagebox,
				},
				id = "margin",
				widget = wibox.container.margin,
				margins = 20,
			},
			widget = wibox.container.background,
			bg = color .. "22",
			shape = helpers.rrect(10),
			shape_border_width = beautiful.border_width_custom,
			shape_border_color = color .. "99",
		},
		widget = wibox.container.place,
		buttons = {
			awful.button({}, 1, function()
				L:close()
				awful.spawn.easy_async_with_shell(command)
			end),
		},
	})
	if path == gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/power.png" then
		helpers.gc(buttons, "icon").forced_width = 25
		helpers.gc(buttons, "icon").forced_height = 25
		helpers.gc(buttons, "margin").margins = 21
	end
	return buttons
end

local sidebar = wibox.widget({
	widget = wibox.container.background,
	bg = beautiful.background,
	forced_width = Conf.entry_height + 20,
	{
		layout = wibox.layout.align.vertical,
		{
			{
				{
					widget = wibox.widget.imagebox,
					image = beautiful.profile,
					forced_height = 60,
					forced_width = 60,
					resize = true,
				},
				widget = wibox.container.place,
			},
			widget = wibox.container.margin,
			top = 15,
		},
		nil,
		{
			{
				createPowerButton(
					gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/lock.png",
					beautiful.blue,
					"awesome-client \"awesome.emit_signal('toggle::lock')\" &"
				),
				createPowerButton(
					gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/restart.png",
					beautiful.green,
					"reboot &"
				),
				createPowerButton(
					gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/power.png",
					beautiful.red,
					"poweroff &"
				),
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
		image = helpers.cropSurface(4, gears.surface.load_uncached(beautiful.wallpaper)),
		opacity = 1,
		forced_height = 120,
		clip_shape = helpers.rrect(10),
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
						font = beautiful.sans .. " 12",
						widget = wibox.widget.textbox,
					},
					{
						markup = "Search...",
						forced_height = 10,
						id = "placeholder",
						font = beautiful.sans .. " 12",
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.stack,
				},
				widget = wibox.container.margin,
				left = 20,
			},
			forced_width = Conf.entry_width - 200,
			forced_height = 55,
			shape = helpers.rrect(10),
			widget = wibox.container.background,
			bg = beautiful.darker .. "50",
			shape_border_width = beautiful.border_width_custom,
			shape_border_color = beautiful.border_color,
		},
		widget = wibox.container.place,
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
	widget = wibox.container.background,
	bg = beautiful.lighter,
	shape = helpers.rrect(10),
	shape_border_width = beautiful.border_width_custom,
	shape_border_color = beautiful.border_color,
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
})

local popup_widget = awful.popup({
	bg = beautiful.lighter,
	ontop = true,
	visible = false,
	placement = function(d)
		helpers.placeWidget(d, "bottom_left", 0, 2, 2, 0)
	end,
	maximum_width = Conf.entry_width + Conf.entry_height + Conf.popup_margins * 3,
	shape = helpers.rrect(10),
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
			shape = helpers.rrect(10),
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
			shape_border_width = beautiful.border_width_custom,
			{
				{
					{
						image = entry.icon,
						clip_shape = helpers.rrect(10),
						forced_height = 70,
						forced_width = 70,
						widget = wibox.widget.imagebox,
					},
					{
						markup = entry.name,
						id = "name",
						widget = wibox.widget.textbox,
						font = beautiful.sans .. " 13",
					},
					layout = wibox.layout.fixed.horizontal,
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
			entry_widget.bg = beautiful.lighter1
			entry_widget.shape_border_color = beautiful.border_color
			helpers.gc(entry_widget, "name"):set_font(beautiful.sans .. " Medium 13")
			helpers.gc(entry_widget, "name"):set_markup_silently(helpers.colorizeText(entry.name, beautiful.blue))
		else
			entry_widget.shape_border_color = beautiful.foreground .. "00"
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
			helpers.gc(prompt, "txt"):set_markup_silently(helpers.gc(prompt, "txt").markup:sub(1, -2))
			filter(helpers.gc(prompt, "txt").markup)
		elseif key == "Delete" then
			helpers.gc(prompt, "txt"):set_markup_silently("")
			filter(helpers.gc(prompt, "txt").markup)
		elseif key == "Return" then
			local entry = filtered[index_entry]
			if entry then
				entry.appinfo:launch()
			else
				awful.spawn.easy_async_with_shell(helpers.gc(prompt, "txt").markup .. " &")
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
		helpers.gc(prompt, "txt"):set_markup_silently(helpers.gc(prompt, "txt").markup .. addition)
		filter(helpers.gc(prompt, "txt").markup)
		if string.len(helpers.gc(prompt, "txt").markup) > 0 then
			helpers.gc(prompt, "placeholder"):set_markup_silently("")
		else
			helpers.gc(prompt, "placeholder"):set_markup_silently("Search...")
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
	helpers.gc(prompt, "txt"):set_markup_silently("")
end

function L:toggle()
	if not popup_widget.visible then
		self:open()
	else
		self:close()
	end
end

return L
