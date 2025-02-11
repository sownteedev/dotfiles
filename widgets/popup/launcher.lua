local awful = require("awful")
local wibox = require("wibox")
local Gio = require("lgi").Gio
local iconTheme = require("lgi").require("Gtk", "3.0").IconTheme.get_default()
local beautiful = require("beautiful")
local gears = require("gears")

local numberOfResult = 5

local prompt = wibox.widget({
	{
		image = _Utils.image.cropSurface(4, gears.surface.load_uncached(_User.Wallpaper)),
		opacity = 1,
		forced_height = 125,
		clip_shape = beautiful.radius,
		forced_width = 500,
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
			forced_width = 250,
			forced_height = 55,
			shape = beautiful.radius,
			widget = wibox.container.background,
			bg = beautiful.darker .. "AA",
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
	forced_width = 450,
})

local main = wibox.widget({
	layout = wibox.layout.fixed.vertical,
	spacing = 15,
	prompt
})

local popup_widget = awful.popup({
	bg = beautiful.lighter,
	ontop = true,
	visible = false,
	placement = function(d)
		_Utils.widget.placeWidget(d, "center", 0, 0, 0, 0)
	end,
	maximum_height = 77.5 * numberOfResult + 15 * 3 + 125,
	shape = beautiful.radius,
	widget = {
		main,
		margins = 15,
		widget = wibox.container.margin,
	},
})

awesome.connect_signal("signal::blur", function(status)
	popup_widget.bg = not status and beautiful.lighter or beautiful.lighter .. "DD"
end)

local index_entry, index_start = 1, 1
local unfiltered, filtered, regfiltered = {}, {}, {}

local lower = string.lower
local len = string.len
local insert = table.insert
local sub = string.sub

local function next()
	if index_entry ~= #filtered then
		index_entry = index_entry + 1
		if index_entry > index_start + numberOfResult - 1 then
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
		index_start = #filtered - numberOfResult + 1
	end
end

local function gen()
	local entries = {}
	for _, entry in ipairs(Gio.AppInfo.get_all()) do
		if entry:should_show() then
			local name = entry:get_name():gsub("&", "&amp;"):gsub("<", "&lt;"):gsub("'", "&#39;")
			local desc = entry:get_description() or "Nothing to show"
			local path = entry:get_icon():to_string()
			local icon_info = iconTheme:lookup_icon(path, 48, 0)
			local p = icon_info and icon_info:get_filename() or _Utils.icon.getIcon(nil, name, name)
			table.insert(entries, { name = name, desc = desc, appinfo = entry, icon = p })
		end
	end
	return entries
end

local function filter(input)
	local clear_input = input:gsub("[%(%)%[%]%%]", "")
	local input_lower = lower(clear_input)
	local input_len = len(clear_input)

	filtered = {}
	regfiltered = {}

	for _, entry in ipairs(unfiltered) do
		local name_lower = lower(entry.name)
		if sub(name_lower, 1, input_len) == input_lower then
			insert(filtered, entry)
		elseif name_lower:match(input_lower) then
			insert(regfiltered, entry)
		end
	end

	local function sort_entries(a, b)
		return lower(a.name) < lower(b.name)
	end

	table.sort(filtered, sort_entries)
	table.sort(regfiltered, sort_entries)

	for i = 1, #regfiltered do
		insert(filtered, regfiltered[i])
	end

	if clear_input ~= "" then
		main:reset()
		main:add(prompt)
		main:add(entries_container)
	else
		main:reset()
		main:add(prompt)
	end

	entries_container:reset()

	for i, entry in ipairs(filtered) do
		local entry_widget = wibox.widget({
			shape = beautiful.radius,
			buttons = {
				awful.button({}, 1, function()
					if index_entry == i then
						entry.appinfo:launch()
						awesome.emit_signal("close::launcher")
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
						clip_shape = beautiful.radius,
						forced_height = 51,
						forced_width = 51,
						widget = wibox.widget.imagebox,
					},
					{
						{
							{
								markup = entry.name,
								id = "name",
								widget = wibox.widget.textbox,
								font = beautiful.sans .. " 13",
							},
							{
								markup = entry.desc,
								id = "desc",
								widget = wibox.widget.textbox,
								font = beautiful.sans .. " 10",
							},
							layout = wibox.layout.fixed.vertical,
							spacing = 5,
						},
						align = "center",
						layout = wibox.container.place,
					},
					spacing = 20,
					layout = wibox.layout.fixed.horizontal,
				},
				left = 20,
				top = 15,
				bottom = 15,
				right = 20,
				widget = wibox.container.margin,
			},
		})

		if index_start <= i and i <= index_start + numberOfResult - 1 then
			entries_container:add(entry_widget)
		end

		if i == index_entry then
			entry_widget.bg = beautiful.lighter1
			entry_widget.shape_border_color = beautiful.border_color
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
	Shift_R = true,
	Shift_L = true,
	Super_R = true,
	Super_L = true,
	Tab = true,
	Alt_R = true,
	Alt_L = true,
	Control_L = true,
	Control_R = true,
	Caps_Lock = true,
	Print = true,
	Insert = true,
	CapsLock = true,
	Home = true,
	End = true,
	Down = true,
	Up = true,
	Left = true,
	Right = true
}

local function has_value(_, val)
	return exclude[val]
end

local prompt_grabber = awful.keygrabber({
	auto_start = true,
	stop_event = "release",
	keypressed_callback = function(self, mod, key, command)
		local addition = ""
		if key == "Escape" then
			awesome.emit_signal("close::launcher")
		elseif key == "BackSpace" then
			_Utils.widget.gc(prompt, "txt"):set_markup_silently(_Utils.widget.gc(prompt, "txt").markup:sub(1, -2))
			filter(_Utils.widget.gc(prompt, "txt").markup)
		elseif key == "Delete" then
			_Utils.widget.gc(prompt, "txt"):set_markup_silently("")
			filter(_Utils.widget.gc(prompt, "txt").markup)
		elseif key == "Return" then
			local entry = filtered[index_entry]
			if entry then
				entry.appinfo:launch()
			end
			awesome.emit_signal("close::launcher")
		elseif key == "Up" then
			back()
		elseif key == "Down" then
			next()
		elseif has_value(nil, key) then
			addition = ""
		else
			addition = key
		end
		_Utils.widget.gc(prompt, "txt"):set_markup_silently(_Utils.widget.gc(prompt, "txt").markup .. addition)
		filter(_Utils.widget.gc(prompt, "txt").markup)
		if string.len(_Utils.widget.gc(prompt, "txt").markup) > 0 then
			_Utils.widget.gc(prompt, "placeholder"):set_markup_silently("")
		else
			_Utils.widget.gc(prompt, "placeholder"):set_markup_silently("Search...")
		end
	end,
})

awesome.connect_signal("close::launcher", function()
	popup_widget.visible = false
	prompt_grabber:stop()
	_Utils.widget.gc(prompt, "txt"):set_markup_silently("")
end)

awesome.connect_signal("toggle::launcher", function()
	if not popup_widget.visible then
		popup_widget.visible = true
		filter("")
		unfiltered = gen()
		prompt_grabber:start()
	else
		awesome.emit_signal("close::launcher")
	end
end)
