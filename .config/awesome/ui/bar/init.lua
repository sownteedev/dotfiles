local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")

require("scripts")
require("ui.bar.calendar")
require("ui.bar.notification")
local Launcher = require("ui.launcher")

local vars = {
	profile_default = false,
	time_default = false,
	dnd = true,
	notif_center_default = false,
	theme_default = false
}

screen.connect_signal("request::desktop_decoration", function(s)
	-- profile --
	local profile = wibox.widget {
		layout = wibox.layout.fixed.horizontal,
		{
			widget = wibox.container.background,
			id = "profile",
			bg = beautiful.background_alt,
			{
				widget = wibox.container.margin,
				margins = { bottom = 8, top = 8, left = 10, right = 8 },
				{
					widget = wibox.widget.textbox,
					text = " ",
					font = beautiful.icon_font .. " 9",
					halign = "center"
				}
			}
		}
	}

	awesome.connect_signal("launcher::control", function()
		vars.profile_default = not vars.profile_default
		if not vars.profile_default then
			profile:get_children_by_id("profile")[1]:set_bg(beautiful.background_alt)
			Launcher:toggle()
		else
			profile:get_children_by_id("profile")[1]:set_bg(beautiful.background_urgent)
			Launcher:toggle()
		end
	end)

	profile:buttons {
		awful.button({}, 1, function()
			awesome.emit_signal("launcher::control")
		end),
	}

	-- Switch theme --
	local themes = wibox.widget {
		layout = wibox.layout.fixed.vertical,
		{
			widget = wibox.container.background,
			id = "theme",
			bg = beautiful.background_alt,
			{
				widget = wibox.container.margin,
				margins = { bottom = 8, top = 8, left = 10, right = 8 },
				{
					widget = wibox.widget.textbox,
					text = " ",
					font = beautiful.icon_font .. " 9",
					halign = "center"
				}
			}
		}
	}

	awesome.connect_signal("launcher::theme", function()
		vars.theme_default = not vars.theme_default
		if not vars.theme_default then
			themes:get_children_by_id("theme")[1]:set_bg(beautiful.background_alt)
			awful.spawn.with_shell("~/.config/scripts/RiceSelect/RiceSelector")
		else
			themes:get_children_by_id("theme")[1]:set_bg(beautiful.background_urgent)
			awful.spawn.with_shell("~/.config/scripts/RiceSelect/RiceSelector")
		end
	end)

	themes:buttons {
		awful.button({}, 1, function()
			awesome.emit_signal("launcher::theme")
		end)
	}

	-- tasklist --
	local tasklist = awful.widget.tasklist {
		screen = s,
		filter = awful.widget.tasklist.filter.currenttags,
		buttons = {
			awful.button({}, 1, function(c)
				c:activate { context = "tasklist", action = "toggle_minimization" }
			end),
			awful.button({}, 3, function(c)
				c:kill { context = "tasklist", action = "close client" }
			end),
		},
		layout = {
			spacing = 5,
			layout = wibox.layout.fixed.horizontal,
		},
		widget_template = {
			spacing = 2,
			{
				wibox.widget.base.make_widget(),
				forced_height = 1,
				id = 'background_role',
				widget = wibox.container.background,
			},
			{
				{
					id = 'clienticon',
					widget = awful.widget.clienticon,
				},
				margins = 4,
				widget = wibox.container.margin
			},
			nil,
			layout = wibox.layout.fixed.vertical,
		}
	}

	-- tray --
	local tray = wibox.widget {
		widget = wibox.container.background,
		bg = beautiful.background_alt,
		{
			layout = wibox.layout.fixed.horizontal,
			{
				widget = wibox.container.place,
				halign = "center",
				{
					widget = wibox.container.margin,
					margins = { top = 4, bottom = 8, left = 8 },
					id = "tray",
					visible = false,
					{
						widget = wibox.widget.systray,
						horizontal = true,
						base_size = 24,
					}
				}
			},
			{
				widget = wibox.container.margin,
				margins = 2,
				{
					widget = wibox.widget.textbox,
					id = "button",
					text = " ",
					font = beautiful.icon_font .. " 13",
					halign = "center",
				}
			},
		}
	}

	awesome.connect_signal("show::tray", function()
		if not tray:get_children_by_id("tray")[1].visible then
			tray:get_children_by_id("button")[1].text = " "
			tray:get_children_by_id("tray")[1].visible = true
		else
			tray:get_children_by_id("button")[1].text = " "
			tray:get_children_by_id("tray")[1].visible = false
		end
	end)

	tray:buttons { awful.button({}, 1, function() awesome.emit_signal("show::tray") end) }

	-- clock --
	local time = wibox.widget {
		layout = wibox.layout.fixed.horizontal,
		{
			widget = wibox.container.background,
			id = "clock",
			bg = beautiful.background_alt,
			{
				widget = wibox.container.margin,
				margins = { bottom = 10, top = 8, left = 10, right = 10 },
				{
					layout = wibox.layout.fixed.horizontal,
					spacing = 4,
					{
						widget = wibox.widget.textclock,
						format = "%H:%M:%S",
						font = beautiful.font1 .. " 9",
						refresh = 1,
						halign = "center"
					}
				}
			}
		}
	}

	awesome.connect_signal("time::calendar", function()
		vars.time_default = not vars.time_default
		if not vars.time_default then
			time:get_children_by_id("clock")[1]:set_bg(beautiful.background_alt)
			awesome.emit_signal("sowntee::calendar_widget")
		else
			time:get_children_by_id("clock")[1]:set_bg(beautiful.background_urgent)
			awesome.emit_signal("sowntee::calendar_widget")
		end
	end)

	time:buttons {
		awful.button({}, 1, function()
			awesome.emit_signal("time::calendar")
		end)
	}

	-- battery --
	local bat = wibox.widget {
		widget = wibox.container.background,
		bg = beautiful.background_alt,
		{
			layout = wibox.layout.stack,
			{
				widget = wibox.container.rotate,
				direction = "east",
				{
					widget = wibox.widget.progressbar,
					id = "progressbar",
					max_value = 100,
					forced_height = 100,
					background_color = beautiful.background_urgent,
				}
			},
			{
				widget = wibox.container.background,
				fg = beautiful.background,
				{
					widget = wibox.widget.imagebox,
					id = "icon",
					valign = "center"
				}
			}
		}
	}

	awesome.connect_signal("bat::value", function(value)
		bat:get_children_by_id("progressbar")[1].value = value
		if value > 70 then
			bat:get_children_by_id("progressbar")[1].color = beautiful.green
		elseif value > 20 then
			bat:get_children_by_id("progressbar")[1].color = beautiful.yellow
		else
			bat:get_children_by_id("progressbar")[1].color = beautiful.red
		end
	end)

	awesome.connect_signal("bat::state", function(value)
		if value == "Discharging" then
			bat:get_children_by_id("icon")[1].text = ""
		else
			bat:get_children_by_id("progressbar")[1].color = beautiful.green
			bat:get_children_by_id("icon")[1].image = beautiful.battery_icon
		end
	end)

	-- dnd --
	local dnd_button = wibox.widget {
		widget = wibox.container.background,
		id = "dnd",
		bg = beautiful.background_alt,
		fg = beautiful.foregraund,
		{
			widget = wibox.container.margin,
			margins = { top = 8, bottom = 8, left = 10, right = 8 },
			{
				widget = wibox.widget.textbox,
				id = "icon",
				text = " ",
				font = beautiful.icon_font .. " 10",
				halign = "center",
			}
		}
	}

	awesome.connect_signal("signal::dnd", function()
		vars.dnd = not vars.dnd
		if not vars.dnd then
			dnd_button:get_children_by_id("icon")[1].text = " "
			naughty.suspend()
		else
			dnd_button:get_children_by_id("icon")[1].text = " "
			naughty.resume()
		end
	end)

	awesome.connect_signal("notif_center::open", function()
		vars.notif_center_default = not vars.notif_center_default
		if not vars.notif_center_default then
			dnd_button:get_children_by_id("dnd")[1]:set_bg(beautiful.background_alt)
			awesome.emit_signal("sowntee::notif_center")
		else
			dnd_button:get_children_by_id("dnd")[1]:set_bg(beautiful.background_urgent)
			awesome.emit_signal("sowntee::notif_center")
		end
	end)

	dnd_button:buttons {
		awful.button({}, 1, function()
			awesome.emit_signal("notif_center::open")
		end),
		awful.button({}, 3, function()
			awesome.emit_signal("signal::dnd")
		end),
	}

	-- bar --
	bar = awful.wibar {
		screen = s,
		position = "bottom",
		height = 40,
		width = s.geometry.width + 800,
		bg = beautiful.background_dark,
		border_width = beautiful.border_width,
		border_color = beautiful.border_color_normal,
		-- margins = { bottom = 10 },
		widget = {
			layout = wibox.layout.flex.horizontal,
			{
				widget = wibox.container.place,
				valign = "top",
				content_fill_horizontal = false,
				{
					widget = wibox.container.margin,
					margins = 5,
					{
						layout = wibox.layout.fixed.horizontal,
						spacing = 15,
						profile,
						time,
						tasklist
					}
				}
			},
			{
				widget = wibox.container.place,
				valign = "bottom",
				content_fill_horizontal = false,
				{
					widget = wibox.container.margin,
					margins = 5,
					{
						layout = wibox.layout.fixed.horizontal,
						spacing = 15,
						tray,
						bat,
						themes,
						dnd_button,
					}
				}
			}
		}
	}
end)

awesome.connect_signal("hide::bar", function()
	bar.visible = not bar.visible
end)
