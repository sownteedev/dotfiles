-- User config
local colorscheme = "one_light"
---------------------------------------------------------------------
local switcher = require("modules.awesome-switcher")
local awful = require("awful")
local gears = require("gears")
local gfs = require("gears.filesystem")
local themes_path = gfs.get_configuration_dir() .. "themes/"

local theme = {}

theme.font = "SF Pro Display 15"
theme.sans = "SF Pro Display"
theme.icon = "Material Design Icons"
theme.useless_gap = 10

-- colors --
local colors = require("themes.colors." .. colorscheme)
theme.background = colors.background
theme.darker = colors.darker
theme.lighter = colors.lighter
theme.foreground = colors.foreground

theme.red = colors.red
theme.green = colors.green
theme.blue = colors.blue
theme.yellow = colors.yellow

theme.wallpaper = colors.wallpaper

-- Get resolution --
theme.width = awful.screen.focused().geometry.width
theme.height = awful.screen.focused().geometry.height

theme.user = string.gsub(os.getenv("USER"), "^%l", string.upper)
theme.profile = "~/.config/awesome/themes/assets/sownteedev.png"
theme.songdefpicture = "~/.config/awesome/themes/assets/defsong.jpg"

-- default vars --
theme.bg_normal = theme.background
theme.fg_normal = theme.foreground

-- borders --
theme.border_width = 0
theme.border_color_normal = theme.blue
theme.border_color_active = theme.foreground

-- taglist --
theme.taglist_bg = theme.background .. "00"
theme.taglist_bg_focus = theme.foreground .. "DD"
theme.taglist_fg_focus = theme.foreground
theme.taglist_bg_urgent = theme.red
theme.taglist_fg_urgent = theme.foreground
theme.taglist_bg_occupied = theme.foreground .. "60"
theme.taglist_fg_occupied = theme.foreground
theme.taglist_bg_empty = theme.foreground .. "20"
theme.taglist_fg_empty = theme.foreground
theme.taglist_disable_icon = true

-- Tray --
theme.bg_systray = theme.lighter
theme.systray_icon_spacing = 10

-- tooltips --
theme.tooltip_bg = theme.background
theme.tooltip_fg = theme.foreground
theme.tooltip_border_width = theme.border_width

-- Awesome Switcher --
switcher.settings.preview_box = true
switcher.settings.preview_box_bg = "#00000025"
switcher.settings.preview_box_border = "#00000025"
switcher.settings.preview_box_fps = 60
switcher.settings.preview_box_delay = 0
switcher.settings.preview_box_title_font = { "SF Pro Display" }
switcher.settings.preview_box_title_font_size_factor = 0.9
switcher.settings.preview_box_title_color = { 255, 255, 255, 1 }
switcher.settings.client_opacity = true
switcher.settings.client_opacity_value = 0.3
switcher.settings.client_opacity_value_selected = 1

-- Titlebar --
theme.titlebar_bg_normal = theme.darker
theme.titlebar_bg_focus = theme.darker

-- Icon layout --
theme.layout_floating = gears.color.recolor_image(themes_path .. "assets/floating.png", theme.foreground)
theme.layout_tile = gears.color.recolor_image(themes_path .. "assets/tile.png", theme.foreground)

local function icons()
	theme.icons = {
		thermometer = {
			quarter = { icon = "︁", size = 30 },
			half = { icon = "", size = 30 },
			three_quarter = { icon = "︁", size = 30 },
			full = { icon = "︁", size = 30 },
		},
		network = {
			wifi_off = { icon = "" },
			wifi_low = { icon = "" },
			wifi_medium = { icon = "" },
			wifi_high = { icon = "" },
			wired_off = { icon = "" },
			wired = { icon = "" },
		},
		bluetooth = {
			on = { icon = "", font = "Nerd Font Mono " },
			off = { icon = "", font = "Nerd Font Mono " },
		},
		battery = {
			bolt = { icon = "" },
			quarter = { icon = "" },
			half = { icon = "" },
			three_quarter = { icon = "" },
			full = { icon = "" },
		},
		volume = {
			off = { icon = "" },
			low = { icon = "" },
			normal = { icon = "" },
			high = { icon = "" },
		},
		bluelight = {
			on = { icon = "" },
			off = { icon = "" },
		},
		airplane = {
			on = { icon = "" },
			off = { icon = "" },
		},
		microphone = {
			on = { icon = "" },
			off = { icon = "" },
		},
		lightbulb = {
			on = { icon = "" },
			off = { icon = "" },
		},
		toggle = {
			on = { icon = "" },
			off = { icon = "" },
		},
		circle = {
			plus = { icon = "" },
			minus = { icon = "" },
		},
		caret = {
			left = { icon = "" },
			right = { icon = "" },
		},
		chevron = {
			down = { icon = "" },
			right = { icon = "" },
		},
		window = { icon = "" },
		file_manager = { icon = "" },
		terminal = { icon = "" },
		-- firefox = { icon = "︁", font = theme.font_awesome_6_brands_font_name },
		-- chrome = { icon = "", font = theme.font_awesome_6_brands_font_name },
		-- code = { icon = "", size = 25 },
		-- git = { icon = "", font = theme.font_awesome_6_brands_font_name },
		-- gitkraken = { icon = "︁", font = theme.font_awesome_6_brands_font_name },
		-- discord = { icon = "︁", font = theme.font_awesome_6_brands_font_name },
		-- telegram = { icon = "︁", font = theme.font_awesome_6_brands_font_name },
		-- spotify = { icon = "", font = theme.font_awesome_6_brands_font_name },
		-- steam = { icon = "︁", font = theme.font_awesome_6_brands_font_name },
		-- vscode = { icon = "﬏", size = 40 },
		-- github = { icon = "", font = theme.font_awesome_6_brands_font_name },
		-- gitlab = { icon = "", font = theme.font_awesome_6_brands_font_name },
		-- youtube = { icon = "", font = theme.font_awesome_6_brands_font_name },
		nvidia = { icon = "︁" },
		system_monitor = { icon = "︁" },
		calculator = { icon = "" },
		vim = { icon = "" },
		emacs = { icon = "" },

		forward = { icon = "" },
		backward = { icon = "" },
		_repeat = { icon = "" },
		shuffle = { icon = "" },

		sun = { icon = "" },
		cloud_sun = { icon = "" },
		sun_cloud = { icon = "" },
		cloud_sun_rain = { icon = "" },
		cloud_bolt_sun = { icon = "" },
		cloud = { icon = "" },
		raindrops = { icon = "" },
		snowflake = { icon = "" },
		cloud_fog = { icon = "" },
		moon = { icon = "" },
		cloud_moon = { icon = "" },
		moon_cloud = { icon = "" },
		cloud_moon_rain = { icon = "" },
		cloud_bolt_moon = { icon = "" },

		poweroff = { icon = "" },
		reboot = { icon = "" },
		suspend = { icon = "" },
		exit = { icon = "" },
		lock = { icon = "" },

		code_pull_request = { icon = "︁" },
		commit = { icon = "" },
		star = { icon = "︁" },
		code_branch = { icon = "" },

		gamepad_alt = { icon = "" },
		lights_holiday = { icon = "" },
		download = { icon = "︁" },
		video_download = { icon = "︁" },
		speaker = { icon = "︁" },
		archeive = { icon = "︁" },
		unlock = { icon = "︁" },
		spraycan = { icon = "" },
		note = { icon = "︁" },
		image = { icon = "︁" },
		envelope = { icon = "" },
		word = { icon = "︁" },
		powerpoint = { icon = "︁" },
		excel = { icon = "︁" },
		camera_retro = { icon = "" },
		keyboard = { icon = "" },
		brightness = { icon = "" },
		circle_exclamation = { icon = "︁" },
		bell = { icon = "" },
		router = { icon = "︁" },
		message = { icon = "︁" },
		xmark = { icon = "" },
		microchip = { icon = "" },
		memory = { icon = "" },
		disc_drive = { icon = "" },
		gear = { icon = "" },
		user = { icon = "" },
		scissors = { icon = "" },
		clock = { icon = "" },
		box = { icon = "" },
		left = { icon = "" },
		video = { icon = "" },
		industry = { icon = "" },
		calendar = { icon = "" },
		hammer = { icon = "" },
		folder_open = { icon = "" },
		launcher = { icon = "" },
		check = { icon = "" },
		trash = { icon = "" },
		list_music = { icon = "" },
		arrow_rotate_right = { icon = "" },
		table_layout = { icon = "" },
		tag = { icon = "" },
		xmark_fw = { icon = "" },
		clouds = { icon = "" },
		circle_check = { icon = "" },
		laptop_code = { icon = "" },
		location_dot = { icon = "" },
		server = { icon = "" },
		-- usb = { icon = "", font = theme.font_awesome_6_brands_font_name },
		usb_drive = { icon = "" },
		signal_stream = { icon = "" },
		car_battery = { icon = "" },
		computer = { icon = "" },
		palette = { icon = "" },
		cube = { icon = "" },
		photo_film = { icon = "" },
		clipboard = { icon = "" },
		atom = { icon = "" },
		magnifying_glass = { icon = "" },
		file = { icon = "" },
		bolt = { icon = "" },
	}
end
icons()

return theme
