local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local helpers = require("helpers")
local beautiful = require("beautiful")

local function hover_button(widget)
	local main_widget = wibox.widget {
		widget = wibox.container.background,
		bg = beautiful.background_alt,
		fg = beautiful.foreground,
		forced_width = 30,
		forced_height = 44,
		widget
	}
	main_widget:connect_signal("mouse::enter", function()
		main_widget.bg = beautiful.accent
		main_widget.fg = beautiful.background
	end)
	main_widget:connect_signal("mouse::leave", function()
		main_widget.bg = beautiful.background_alt
		main_widget.fg = beautiful.foreground
	end)
	return main_widget
end

-- widgets --
local reveal_button = hover_button({
	widget = wibox.widget.textbox,
	align = "center",
	text = ""
})

local refresh_button = hover_button({
	widget = wibox.widget.textbox,
	align = "center",
	text = ""
})

local massage_container = wibox.widget {
	widget = wibox.container.background,
	fg = beautiful.foreground_alt,
	forced_height = 420,
	{
		widget = wibox.widget.textbox,
		align = "center"
	}
}

local active_widget_container = wibox.widget {
	layout = wibox.layout.fixed.vertical
}

local wifi_widget_container = wibox.widget {
	layout = wibox.layout.fixed.vertical
}

local bottombar = wibox.widget {
	widget = wibox.container.background,
	bg = beautiful.background_alt,
	forced_height = 50,
	{
		widget = wibox.container.margin,
		margins = 10,
		{
			layout = wibox.layout.align.horizontal,
			refresh_button,
			nil,
			reveal_button
		}
	}
}

local main = wibox.widget {
	widget = wibox.container.background,
	{
		layout = wibox.layout.fixed.vertical,
		spacing = 20,
		{
			widget = wibox.container.background,
			forced_height = 408,
			{
				widget = wibox.container.margin,
				margins = 10,
				{
					layout = wibox.layout.fixed.vertical,
					active_widget_container,
					wifi_widget_container
				}
			}
		},
		bottombar
	}
}

-- functions
local wifi_status = nil

local function refresh()
	wifi_widget_container:reset()
	active_widget_container:reset()
	_G.update_wifi_status()
end

local function send_notification(stdout, stderr, ssid)
	if stdout:match("successfully") then
		naughty.notification {
			title = "Wifi",
			text = "connect successfully to\n" .. ssid,
			icon = beautiful.notification_wifi_icon,
		}
	elseif stderr:match("Error") then
		naughty.notification {
			urgency = "critical",
			title = "Wifi",
			text = "failed to connect\n" .. ssid,
			icon = beautiful.notification_wifi_icon,
		}
	end
end

local function connect(ssid, bssid, security)
	wifi_widget_container:reset()
	active_widget_container:reset()
	local nmcli = "nmcli device wifi connect "

	if security:match("WPA") then
		awful.keygrabber.stop()
		wifi_widget_container:add(massage_container)
		awful.prompt.run {
			prompt = ssid .. "\n\nPassword: ",
			textbox = massage_container.widget,
			bg_cursor = beautiful.foreground,
			done_callback = function()
				refresh()
			end,
			exe_callback = function(input)
				awful.spawn.easy_async_with_shell(nmcli .. bssid .. " password " .. input, function(stdout, stderr)
					send_notification(stdout, stderr, ssid)
				end)
			end
		}
	else
		awful.spawn.easy_async_with_shell(nmcli .. bssid, function(stdout, stderr)
			send_notification(stdout, stderr, ssid)
			refresh()
		end)
	end
end

local function add_entries(list)
	wifi_widget_container:reset()
	active_widget_container:reset()
	for _, entry in ipairs(list) do
		local entry_info = wibox.widget {
			widget = wibox.widget.textbox
		}
		local wifi_entry = wibox.widget {
			widget = wibox.container.background,
			forced_height = 54,
			{
				widget = wibox.container.margin,
				margins = 10,
				{
					layout = wibox.layout.align.horizontal,
					{
						widget = wibox.widget.textbox,
						text = entry.ssid
					},
					nil,
					entry_info
				}
			}
		}

		if entry.active:match("yes") then
			entry_info.text = "connected"
			active_widget_container:add(wifi_entry)
		else
			entry_info.text = entry.security
			wifi_entry.buttons = {
				awful.button({}, 1, function()
					connect(entry.ssid, entry.bssid, entry.security)
				end)
			}
			wifi_widget_container:add(wifi_entry)
		end
	end
end

local function get_wifi()
	local wifi_list = {}
	local nmcli = "nmcli -t -f 'SSID, BSSID, SECURITY, ACTIVE' device wifi list"
	wifi_widget_container:add(massage_container)
	massage_container.widget.markup = helpers.ui.colorizeText("Please wait\nor refresh one more time", beautiful.background_urgent)
	-- It could be done much easier with io.popen()
	-- but since nmcli sometimes recieves data for very long time it freeze wm
	-- so as marked in doc you should use awful.spawn.with_line_callback() for asynchrony
	-- and idk it sometimes causes some functions not working properly
	-- therefore you have to refresh many times
	awful.spawn.with_line_callback(nmcli, {
		stdout = function(line)
			local ssid, bssid_raw, security, active = line:gsub([[\:]], [[\t]]):match("(.*):(.*):(.*):(.*)")
			local bssid = string.gsub(bssid_raw, [[\t]], ":")
			table.insert(wifi_list, { ssid = ssid, bssid = bssid, security = security, active = active })
		end,
		output_done = function()
			add_entries(wifi_list)
		end
	})
end

function update_wifi_status()
	awful.spawn.easy_async_with_shell("nmcli g | sed 1d | awk '{print $4}'", function(stdout)
		if stdout:match("enabled") then
			wifi_status = true
			awesome.emit_signal("wifi::enabled")
			get_wifi()
		else
			wifi_status = false
			awesome.emit_signal("wifi::disabled")
			wifi_widget_container:add(massage_container)
			massage_container.widget.text = "Wifi disabled"
		end
	end)
end
update_wifi_status()

local function wifi_toggle()
	if wifi_status then
		awful.spawn.easy_async_with_shell("nmcli radio wifi off", function()
			refresh()
		end)
	else
		awful.spawn.easy_async_with_shell("nmcli radio wifi on", function()
			refresh()
		end)
	end
end

awesome.connect_signal("wifi::toggle", function()
	wifi_toggle()
end)

awesome.connect_signal("wifi::show", function()
	refresh()
end)

wifi_widget_container:buttons(gears.table.join(
	awful.button({}, 4, nil, function()
		if #wifi_widget_container.children == 1 then
			return
		end
		wifi_widget_container:insert(1, wifi_widget_container.children[#wifi_widget_container.children])
		wifi_widget_container:remove(#wifi_widget_container.children)
	end),

	awful.button({}, 5, nil, function()
		if #wifi_widget_container.children == 1 then
			return
		end
		wifi_widget_container:insert(#wifi_widget_container.children + 1, wifi_widget_container.children[1])
		wifi_widget_container:remove(1)
	end)
))

reveal_button:buttons(gears.table.join(awful.button({}, 1, function()
	awesome.emit_signal("summon::wifi_popup")
end)))

refresh_button:buttons(gears.table.join(awful.button({}, 1, function()
	refresh()
end)))

local wifi_popup = awful.popup {
	visible = false,
	ontop = true,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	minimum_width = 390,
	minimum_height = 478,
	placement = function(d)
		awful.placement.centered(d, { honor_workarea = false })
	end,
	widget = main,
}

-- summon functions --

awesome.connect_signal("summon::wifi_popup", function()
	wifi_popup.visible = not wifi_popup.visible
end)

-- hide on click --


client.connect_signal("button::press", function()
	wifi_popup.visible = false
end)

awful.mouse.append_global_mousebinding(
	awful.button({ }, 1, function()
		wifi_popup.visible = false
	end)
)



return main
