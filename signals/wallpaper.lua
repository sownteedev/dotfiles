local awful = require("awful")
local config_file = os.getenv("HOME") .. "/.config/awesome/user.lua"

function changewall(path)
	local command = "sed -i 's|_User.Wallpaper       = .*|_User.Wallpaper       = \"" ..
		path .. "\"|' " .. config_file
	awful.spawn.easy_async_with_shell(command, function()
		_User.Wallpaper = path
		awesome.emit_signal("wallpaper::change")
	end)
end

function changelockwall(path)
	local command = "sed -i 's|_User.Lock            = .*|_User.Lock            = \"" .. path .. "\"|' " .. config_file
	awful.spawn.easy_async_with_shell(command, function()
		_User.Lock = path
		awesome.emit_signal("lock::change")
	end)
end

local awful = require('awful')
local gears = require('gears')
local wibox = require('wibox')
local beautiful = require("beautiful")

local function create_letter_wibox(letter, color, font_size)
	return wibox.widget {
		font = "awesomewm-font " .. font_size,
		markup = "<span foreground='" .. color .. "'>" .. letter .. "</span>",
		widget = wibox.widget.textbox
	}
end

local function create_awesome_wallpaper(args)
	local args = gears.table.crush({
		background_color = beautiful.darker,
		letter_colors = { "#fca2aa", "#F8BD96", "#fbeab9", "#9ce5c0", "#c7e5d6", "#bac8ef", "#d7c1ed", "#8fa3b3", "#b4b6d9" },
		font_size = 65,
		solid_letters = true,
		spacing = 15
	}, args or {})

	local string = "AWESOMEWM"
	local letters = args.solid_letters and string or string.lower(string)
	local word_widget = wibox.layout.fixed.horizontal()
	word_widget.spacing = args.spacing

	for i = 1, #letters do
		word_widget:add(create_letter_wibox(letters:sub(i, i), args.letter_colors[i], args.font_size))
	end

	screen.connect_signal("request::wallpaper", function(s)
		awful.wallpaper {
			screen = s,
			bg = bg_color,
			widget = wibox.widget {
				word_widget,
				valign = "center",
				halign = "center",
				widget = wibox.container.place
			}
		}
	end)
end

create_awesome_wallpaper()

