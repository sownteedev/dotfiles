-- User config
local colorscheme = "dark"
require("themes.toggle")
---------------------------------------------------------------------
local gears      = require("gears")
local gfs        = require("gears.filesystem")
local helpers    = require("helpers")

local theme      = {}

theme.font       = "SF Pro Display 12"
theme.sans       = "SF Pro Display"
theme.icon       = "Material Design Icons"
theme.icon_path  = gfs.get_configuration_dir() .. "themes/" .. "assets/"
theme.iconsss    = "WhiteSur"

-- Colors --
local colors     = require("themes.colors." .. colorscheme)
theme.background = colors.background
theme.darker     = colors.darker
theme.foreground = colors.foreground
theme.red        = colors.red
theme.green      = colors.green
theme.blue       = colors.blue
theme.yellow     = colors.yellow

theme.wallpaper  = colors.wallpaper
theme.type       = colors.type

if theme.type == "dark" then
	theme.fg = helpers.blend(theme.background, theme.foreground, 0.1)
	theme.fg1 = helpers.blend(theme.background, theme.foreground, 0.9)
else
	theme.fg = helpers.blend(theme.background, theme.foreground, 0.9)
	theme.fg1 = helpers.blend(theme.background, theme.foreground, 0.1)
end

theme.autohidedock         = false

theme.width                = 2560
theme.height               = 1600
theme.useless_gap          = 10
theme.radius               = helpers.rrect(10)

theme.user                 = os.getenv("USER")
theme.profile              = theme.icon_path .. "sownteedev.png"
theme.songdefpicture       = theme.icon_path .. "music/artdefault.jpg"
theme.lock                 = "$HOME/.walls/lockart.jpg"

-- Default vars --
theme.bg_normal            = theme.background
theme.fg_normal            = theme.foreground

-- Borders --
theme.border_width         = 0
theme.border_color_normal  = theme.foreground
theme.border_color_active  = theme.foreground

-- Taglist --
theme.taglist_font         = theme.sans .. " Medium 12"
theme.taglist_bg           = theme.background .. "00"
theme.taglist_bg_focus     = theme.background .. "00"
theme.taglist_fg_focus     = theme.foreground
theme.taglist_bg_urgent    = theme.background .. "00"
theme.taglist_fg_urgent    = theme.red
theme.taglist_bg_occupied  = theme.background .. "00"
theme.taglist_fg_occupied  = theme.foreground .. "AA"
theme.taglist_bg_empty     = theme.background .. "00"
theme.taglist_fg_empty     = theme.foreground .. "88"
theme.taglist_disable_icon = true

-- Tray --
theme.systray_icon_spacing = 25

-- Tooltips --
theme.tooltip_bg           = theme.background
theme.tooltip_fg           = theme.foreground
theme.tooltip_border_width = theme.border_width

-- Icon layout --
theme.layout_floating      = gears.color.recolor_image(theme.icon_path .. "awm/floating.png",
	theme.foreground)
theme.layout_tile          = gears.color.recolor_image(theme.icon_path .. "awm/tile.png",
	theme.foreground)

-- Snap --
theme.snap_bg              = theme.foreground
theme.snap_shape           = theme.radius
theme.snapper_gap          = 0
theme.snap_border_width    = 2

return theme
