-- User config
local colorscheme = "one_light"
require("themes.toggle")
---------------------------------------------------------------------
local switcher                                       = require("modules.awesome-switcher")
local awful                                          = require("awful")
local gears                                          = require("gears")
local gfs                                            = require("gears.filesystem")
local helpers                                        = require("helpers")
local themes_path                                    = gfs.get_configuration_dir() .. "themes/"

local theme                                          = {}

theme.font                                           = "SF Pro Display 15"
theme.sans                                           = "SF Pro Display"
theme.icon                                           = "Material Design Icons"

-- colors --
local colors                                         = require("themes.colors." .. colorscheme)
theme.background                                     = colors.background
theme.darker                                         = colors.darker
theme.lighter                                        = colors.lighter
theme.lighter1                                       = colors.lighter1
theme.foreground                                     = colors.foreground

theme.red                                            = colors.red
theme.green                                          = colors.green
theme.blue                                           = colors.blue
theme.yellow                                         = colors.yellow

theme.wallpaper                                      = colors.wallpaper

theme.width                                          = 2560
theme.height                                         = 1600
theme.useless_gap                                    = 10

theme.user                                           = os.getenv("USER")
theme.profile                                        = themes_path .. "assets/sownteedev.png"
theme.songdefpicture                                 = themes_path .. "assets/music/defsong.jpg"
theme.lock                                           = "$HOME/.walls/4028603.jpg"

-- default vars --
theme.bg_normal                                      = theme.background
theme.fg_normal                                      = theme.foreground

-- borders --
theme.border_width                                   = 0
theme.border_width_custom                            = 1
theme.border_color                                   = theme.foreground .. "33"
theme.border_color_normal                            = theme.blue
theme.border_color_active                            = theme.foreground

-- taglist --
theme.taglist_bg                                     = theme.background .. "00"
theme.taglist_bg_focus                               = theme.lighter1
theme.taglist_fg_focus                               = theme.foreground
theme.taglist_bg_urgent                              = theme.background .. "00"
theme.taglist_fg_urgent                              = theme.red .. "FF"
theme.taglist_bg_occupied                            = theme.background .. "00"
theme.taglist_fg_occupied                            = theme.foreground .. "BB"
theme.taglist_bg_empty                               = theme.background .. "00"
theme.taglist_fg_empty                               = theme.foreground .. "55"
theme.taglist_disable_icon                           = true

-- Tray --
theme.bg_systray                                     = theme.lighter
theme.systray_icon_spacing                           = 10

-- tooltips --
theme.tooltip_bg                                     = theme.background
theme.tooltip_fg                                     = theme.foreground
theme.tooltip_border_width                           = theme.border_width

-- Awesome Switcher --
switcher.settings.preview_box                        = true
switcher.settings.preview_box_bg                     = "#00000025"
switcher.settings.preview_box_border                 = "#00000025"
switcher.settings.preview_box_fps                    = 60
switcher.settings.preview_box_delay                  = 0
switcher.settings.preview_box_title_font             = { "SF Pro Display" }
switcher.settings.preview_box_title_font_size_factor = 0.8
switcher.settings.preview_box_title_color            = { 255, 255, 255, 1 }
switcher.settings.client_opacity                     = true
switcher.settings.client_opacity_value               = 0.3
switcher.settings.client_opacity_value_selected      = 1

-- Titlebar --
theme.titlebar_bg                                    = theme.lighter
theme.titlebar_bg_normal                             = theme.lighter
theme.titlebar_bg_focus                              = theme.lighter

-- Icon layout --
theme.layout_floating                                = gears.color.recolor_image(themes_path .. "assets/floating.png",
	theme.foreground)
theme.layout_tile                                    = gears.color.recolor_image(themes_path .. "assets/tile.png",
	theme.foreground)

theme.snap_bg                                        = theme.foreground
theme.snap_shape                                     = helpers.rrect(10)
theme.snapper_gap                                    = 0
theme.snap_border_width                              = 2

return theme
