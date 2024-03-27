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
theme.useless_gap = 10

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

return theme
