local gears   = require("gears")
local gfs     = require("gears.filesystem")
local helpers = require("helpers")
require("themes.toggle")

local theme                = {}

theme.font                 = "SF Pro Display 12"
theme.sans                 = "SF Pro Display"
theme.icon                 = "Material Design Icons"
theme.icon_path            = gfs.get_configuration_dir() .. "themes/assets/"

-- Colors --
local colors               = require("themes.colors." .. _User.Colorscheme)
theme.type                 = colors.type
theme.background           = colors.background
theme.foreground           = colors.foreground
theme.red                  = colors.red
theme.green                = colors.green
theme.blue                 = colors.blue
theme.yellow               = colors.yellow

theme.darker               = helpers.change_hex_lightness(theme.background, -3)
theme.lighter              = helpers.change_hex_lightness(theme.background, 3)
theme.lighter1             = helpers.change_hex_lightness(theme.background, 6)
theme.lighter2             = helpers.change_hex_lightness(theme.background, 9)

theme.width                = screen.primary.geometry.width
theme.height               = screen.primary.geometry.height
theme.radius               = helpers.rrect(10)
theme.useless_gap          = 10

-- Default vars --
theme.bg_normal            = theme.background
theme.fg_normal            = theme.foreground

-- Borders --
theme.border_width         = 0
theme.border_color_normal  = theme.foreground
theme.border_color_active  = theme.foreground

-- Taglist --
theme.taglist_bg           = theme.background .. "00"
theme.taglist_bg_focus     = theme.background .. "00"
theme.taglist_fg_focus     = theme.foreground
theme.taglist_bg_urgent    = theme.background .. "00"
theme.taglist_fg_urgent    = theme.red
theme.taglist_bg_occupied  = theme.background .. "00"
theme.taglist_fg_occupied  = theme.foreground
theme.taglist_bg_empty     = theme.background .. "00"
theme.taglist_fg_empty     = theme.foreground .. "AA"
theme.taglist_disable_icon = true

-- Tray --
theme.systray_icon_spacing = 28

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
