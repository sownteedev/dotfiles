local awful = require("awful")
local wibox = require("wibox")
local Gio = require("lgi").Gio
local beautiful = require("beautiful")

local L = {}

local Conf = {
	rows = 8,
	entry_height = 45,
	entry_width = 250,
	popup_margins = 15,
}

local function hover_button(widget, color, fg)
	local box = wibox.widget {
		widget = wibox.container.background,
		bg = beautiful.background_alt,
		fg = fg or beautiful.foreground,
		forced_width = Conf.entry_height,
		forced_height = Conf.entry_height,
		widget
	}
	box:connect_signal("mouse::enter", function()
		box.bg = color
		box.fg = beautiful.background
	end)
	box:connect_signal("mouse::leave", function()
		box.bg = beautiful.background_alt
		box.fg = fg or beautiful.foreground
	end)
	return box
end

local control_center_button = hover_button(
	wibox.widget {
		widget = wibox.widget.textbox,
		markup = "",
		font = beautiful.icon_font .. " 15",
		align = "center"
	},
	beautiful.accent, beautiful.foreground
)

local restart_button = hover_button(
	wibox.widget {
		widget = wibox.widget.textbox,
		markup = "",
		font = beautiful.icon_font .. " 15",
		align = "center"
	},
	beautiful.blue, beautiful.blue
)

local poweroff_button = hover_button(
	wibox.widget {
		widget = wibox.widget.textbox,
		markup = "󰐥",
		font = beautiful.icon_font .. " 15",
		align = "center"
	},
	beautiful.red, beautiful.red
)

local lock_button = hover_button(
	wibox.widget {
		widget = wibox.widget.textbox,
		markup = "",
		font = beautiful.icon_font .. " 15",
		align = "center"
	},
	beautiful.yellow, beautiful.yellow
)

local quit_button = hover_button(
	wibox.widget {
		widget = wibox.widget.textbox,
		markup = "󰍃",
		font = beautiful.icon_font .. " 15",
		align = "center"
	},
	beautiful.green, beautiful.green
)

local sidebar = wibox.widget {
	widget = wibox.container.background,
	bg = beautiful.background_alt,
	forced_width = Conf.entry_height,
	{
		layout = wibox.layout.align.vertical,
		control_center_button,
		nil,
		{
			layout = wibox.layout.fixed.vertical,
			lock_button,
			quit_button,
			restart_button,
			poweroff_button
		}
	}
}

local prompt = wibox.widget {
	widget = wibox.widget.textbox
}

local promptbox = wibox.widget {
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

local entries_container = wibox.widget {
	layout = wibox.layout.grid,
	homogeneous = false,
	expand = true,
	forced_num_cols = 1,
	forced_width = Conf.entry_width,
}

local main_widget = wibox.widget {
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

local popup_widget = awful.popup {
	bg = beautiful.background,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	ontop = true,
	visible = false,
	placement = function(d)
		awful.placement.bottom_left(d, { honor_workarea = true, margins = 10 + beautiful.border_width * 2 })
	end,
	maximum_width = Conf.entry_width + Conf.entry_height + Conf.popup_margins * 3,
	widget = main_widget
}

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
			table.insert(entries, { name = name, appinfo = entry })
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
				margins = 10,
				widget = wibox.container.margin,
				{
					markup = entry.name,
					widget = wibox.widget.textbox,
					font = beautiful.font1 .. " 10",
				}
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
		prompt = "  ",
		font = beautiful.font1 .. " 11",
		textbox = prompt,
		bg_cursor = beautiful.background_alt,
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

control_center_button.buttons = {
	awful.button({}, 1, function()
		awesome.emit_signal("sowntee::control")
	end)
}

restart_button.buttons = {
	awful.button({}, 1, function()
		awful.spawn.with_shell("reboot")
	end)
}

poweroff_button.buttons = {
	awful.button({}, 1, function()
		awful.spawn.with_shell("poweroff")
	end)
}

lock_button.buttons = {
	awful.button({}, 1, function()
		awful.spawn.with_shell("betterlockscreen -l dimblur")
	end)
}

quit_button.buttons = {
	awful.button({}, 1, function()
		awesome.quit()
	end)
}

return L
