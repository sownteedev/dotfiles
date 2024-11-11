local awful = require("awful")
local wibox = require('wibox')
local beautiful = require("beautiful")

local CONFIG_FILE = os.getenv("HOME") .. "/.config/awesome/user.lua"
local WALLPAPER_TEMPLATE = '_User.Wallpaper       = "%s"'
local LOCK_TEMPLATE = '_User.Lock            = "%s"'

local function create_sed_command(template, path)
	return string.format(
		"sed -i 's|%s|%s|' %s",
		template:gsub('%%s', '.*'),
		template:format(path),
		CONFIG_FILE
	)
end

function changewall(path)
	awful.spawn.easy_async_with_shell(
		create_sed_command(WALLPAPER_TEMPLATE, path),
		function()
			_User.Wallpaper = path
			awesome.emit_signal("wallpaper::change")
		end
	)
end

function changelockwall(path)
	awful.spawn.easy_async_with_shell(
		create_sed_command(LOCK_TEMPLATE, path),
		function()
			_User.Lock = path
			awesome.emit_signal("lock::change")
		end
	)
end

local AWESOME_SETTINGS = {
	colors = {
		"#fca2aa", "#F8BD96", "#fbeab9", "#9ce5c0",
		"#c7e5d6", "#bac8ef", "#d7c1ed", "#8fa3b3",
		"#b4b6d9"
	},
	font_size = 65,
	text = "AWESOMEWM",
	spacing = 15
}

function create_awesome_wallpaper()
	local word_widget = wibox.layout.fixed.horizontal()
	word_widget.spacing = AWESOME_SETTINGS.spacing

	for i = 1, #AWESOME_SETTINGS.text do
		word_widget:add(wibox.widget {
			font = "awesomewm-font " .. AWESOME_SETTINGS.font_size,
			markup = string.format(
				"<span foreground='%s'>%s</span>",
				AWESOME_SETTINGS.colors[i],
				AWESOME_SETTINGS.text:sub(i, i)
			),
			widget = wibox.widget.textbox
		})
	end

	screen.connect_signal("request::wallpaper", function(s)
		awful.wallpaper {
			screen = s,
			bg = beautiful.darker,
			widget = wibox.widget {
				word_widget,
				valign = "center",
				halign = "center",
				widget = wibox.container.place
			}
		}
	end)
end
