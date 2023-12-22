local awful                             = require("awful")
local wibox                             = require("wibox")
local Gio                               = require("lgi").Gio
local iconTheme                         = require("lgi").require("Gtk", "3.0").IconTheme.get_default()
local beautiful                         = require("beautiful")
local helpers                           = require("helpers")
local dpi                               = beautiful.xresources.apply_dpi

local L                                 = {}

local Conf                              = {
	rows = 8,
	entry_height = 50,
	entry_width = 250,
	popup_margins = 15,
}

local createPowerButton                 = function(icon, color, command)
	return wibox.widget {
		{
			{
				{
					markup = helpers.colorizeText(icon, color),
					align = "center",
					font = beautiful.icon_font .. " 13",
					widget = wibox.widget.textbox,
				},
				widget = wibox.container.margin,
				left = 8,
				right = 0,
				top = 5,
				bottom = 5,
			},
			widget = wibox.container.background,
			bg = color .. '11',
			shape = helpers.rrect(4)
		},
		widget = wibox.container.place,
		halign = "center",
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.with_shell(command)
			end)
		},
	}
end

local sidebar                           = wibox.widget {
	widget = wibox.container.background,
	bg = beautiful.background_alt,
	forced_width = Conf.entry_height,
	shape = helpers.rrect(5),
	{
		layout = wibox.layout.align.vertical,
		{
			{
				{
					widget = wibox.widget.imagebox,
					image = beautiful.image,
					forced_height = 40,
					forced_width = 40,
					resize = true,
				},
				widget = wibox.container.place,
				halign = "center"
			},
			widget = wibox.container.margin,
			top = 15
		},
		nil,
		{
			{
				createPowerButton(" ", beautiful.blue, "betterlockscreen -l dimblur"),
				createPowerButton(" ", beautiful.yellow, "reboot"),
				createPowerButton("󰐥 ", beautiful.red, "poweroff"),
				spacing = 10,
				layout = wibox.layout.fixed.vertical
			},
			widget = wibox.container.margin,
			margins = 10,
		},
	}
}

local prompt                            = wibox.widget {
	widget = wibox.widget.textbox
}

local promptbox                         = wibox.widget {
	widget = wibox.container.background,
	bg = beautiful.border_color_normal,
	forced_height = Conf.entry_height,
	forced_width = Conf.entry_width,
	buttons = {
		awful.button({}, 1, function()
			L:open()
		end)
	},
	{
		widget = wibox.container.margin,
		margins = { bottom = beautiful.border_width },
		{
			widget = wibox.container.background,
			bg = beautiful.background,
			{
				widget = wibox.container.margin,
				margins = { left = 10, right = 10 },
				prompt
			}
		}
	}
}

local entries_container                 = wibox.widget {
	layout = wibox.layout.grid,
	homogeneous = false,
	expand = true,
	forced_num_cols = 1,
	forced_width = Conf.entry_width,
}

local main_widget                       = wibox.widget {
	widget = wibox.container.margin,
	margins = Conf.popup_margins,
	{
		widget = wibox.container.background,
		forced_height = (Conf.entry_height * (Conf.rows + 1)) + Conf.popup_margins,
		{
			layout = wibox.layout.fixed.horizontal,
			spacing = Conf.popup_margins,
			fill_space = true,
			{
				layout = wibox.layout.fixed.vertical,
				spacing = Conf.popup_margins,
				promptbox,
				entries_container
			},
			sidebar
		}
	}
}

local popup_widget                      = awful.popup {
	bg = beautiful.background,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	ontop = true,
	visible = false,
	placement = function(d)
		awful.placement.bottom_left(d, { honor_workarea = true, margins = 10 + beautiful.border_width * 2 })
	end,
	maximum_width = Conf.entry_width + 100 + Conf.entry_height + Conf.popup_margins * 3,
	shape = helpers.rrect(5),
	widget = main_widget
}

local index_entry, index_start          = 1, 1
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
					local icon_info = iconTheme:lookup_icon(path, dpi(48), 0)
					local p = icon_info and icon_info:get_filename()
					path = p
				end
			end
			table.insert(
				entries,
				{ name = name, appinfo = entry, icon = path or '' }
			)
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

	table.sort(filtered, function(a, b) return a.name:lower() < b.name:lower() end)
	table.sort(regfiltered, function(a, b) return a.name:lower() < b.name:lower() end)

	for i = 1, #regfiltered do
		filtered[#filtered + 1] = regfiltered[i]
	end

	entries_container:reset()

	for i, entry in ipairs(filtered) do
		local entry_widget = wibox.widget {
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
						valign = 'center',
						widget = wibox.widget.imagebox
					},
					{
						markup = entry.name,
						id = "name",
						widget = wibox.widget.textbox,
						font = beautiful.sans .. " 10",
					},
					layout = wibox.layout.fixed.horizontal,
					spacing = 20,
				},
				margins = dpi(10),
				widget = wibox.container.margin,
			}
		}

		if index_start <= i and i <= index_start + Conf.rows - 1 then
			entries_container:add(entry_widget)
		end

		if i == index_entry then
			entry_widget.bg = beautiful.background_alt
			entry_widget.fg = beautiful.foreground
		end
	end

	if index_entry > #filtered then
		index_entry, index_start = 1, 1
	elseif index_entry < 1 then
		index_entry = 1
	end

	collectgarbage("collect")
end

local function send_signal()
	awesome.emit_signal("launcher::visibility", popup_widget.visible)
end

function L:open()
	popup_widget.visible = true
	send_signal()

	index_start, index_entry = 1, 1
	unfiltered = gen()
	filter("")

	awful.keygrabber.stop()
	awful.prompt.run {
		prompt = "   ",
		font = beautiful.font1 .. " 12",
		textbox = prompt,
		bg_cursor = beautiful.background,
		done_callback = function()
			self:close()
		end,
		changed_callback = function(input)
			filter(input)
		end,
		exe_callback = function(input)
			if filtered[index_entry] then
				filtered[index_entry].appinfo:launch()
			else
				awful.spawn.with_shell(input)
			end
		end,
		keypressed_callback = function(_, key)
			if key == "Down" then
				next()
			elseif key == "Up" then
				back()
			end
		end
	}
end

function L:close()
	popup_widget.visible = false
	send_signal()
	awful.keygrabber.stop()
end

function L:toggle()
	if not popup_widget.visible then
		self:open()
	else
		self:close()
	end
end

return L
