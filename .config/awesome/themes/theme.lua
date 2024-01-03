-- User config
local colorscheme = "yoru"
---------------------------------------------------------------------
local switcher                                       = require("modules.awesome-switcher")
local awful                                          = require("awful")
local gears                                          = require("gears")
local gfs                                            = require("gears.filesystem")
local themes_path                                    = gfs.get_configuration_dir() .. "themes/"

local theme                                          = {}

theme.font                                           = "Rubik 10"
theme.sans                                           = "Rubik"
theme.icon                                           = "Material Design Icons"
theme.useless_gap                                    = 10

-- colors --
local colors                                         = require("themes.colors." .. colorscheme)
theme.background                                     = colors.background
theme.background_dark                                = colors.background_dark
theme.background_alt                                 = colors.background_alt
theme.background_urgent                              = colors.background_urgent
theme.background_urgent1                             = colors.background_urgent1
theme.foreground                                     = colors.foreground

theme.red                                            = colors.red
theme.green                                          = colors.green
theme.blue                                           = colors.blue
theme.yellow                                         = colors.yellow
theme.orange                                         = colors.orange
theme.violet                                         = colors.violet
theme.accent                                         = colors.accent

theme.wallpaper                                      = colors.wallpaper

-- Get resolution --
theme.width                                          = awful.screen.focused().geometry.width
theme.height                                         = awful.screen.focused().geometry.height

theme.user                                           = string.gsub(os.getenv('USER'), '^%l', string.upper)
theme.profile                                        = "~/.config/awesome/themes/assets/sownteedev.png"
theme.fetch                                          = "~/.config/awesome/themes/assets/neofetch.png"
theme.songdefpicture                                 = "~/.config/awesome/themes/assets/defsong.jpg"

-- Awesome Switcher --
switcher.settings.preview_box                        = true
switcher.settings.preview_box_bg                     = "#00000030"
switcher.settings.preview_box_border                 = "#00000030"
switcher.settings.preview_box_fps                    = 60
switcher.settings.preview_box_delay                  = 0
switcher.settings.preview_box_title_font             = { "Manrope" }
switcher.settings.preview_box_title_font_size_factor = 1
switcher.settings.preview_box_title_color            = { 255, 255, 255, 1 }

switcher.settings.client_opacity                     = true
switcher.settings.client_opacity_value               = 0.5
switcher.settings.client_opacity_value_in_focus      = 0.5
switcher.settings.client_opacity_value_selected      = 1

switcher.settings.cycle_raise_client                 = true

-- borders --
theme.border_width                                   = 0
theme.border_color_normal                            = theme.background_urgent
theme.border_color_active                            = theme.accent

-- default vars --
theme.bg_normal                                      = theme.background
theme.fg_normal                                      = theme.foreground

-- tasklist --
theme.tasklist_bg_normal                             = theme.background
theme.tasklist_bg_focus                              = theme.background_alt
theme.tasklist_bg_minimize                           = theme.background_urgent

-- taglist --
theme.taglist_bg                                     = theme.background .. "00"
theme.taglist_bg_focus                               = theme.accent
theme.taglist_fg_focus                               = theme.foreground
theme.taglist_bg_urgent                              = theme.red
theme.taglist_fg_urgent                              = theme.foreground
theme.taglist_bg_occupied                            = theme.green .. '70'
theme.taglist_fg_occupied                            = theme.foreground
theme.taglist_bg_empty                               = theme.foreground .. '33'
theme.taglist_fg_empty                               = theme.foreground
theme.taglist_disable_icon                           = true

-- Tray --
theme.bg_systray                                     = theme.background_alt
theme.systray_icon_spacing                           = 10

-- tooltips --
theme.tooltip_bg                                     = theme.background
theme.tooltip_fg                                     = theme.foreground
theme.tooltip_border_width                           = theme.border_width

-- Titlebar --
theme.titlebar_bg_normal                             = theme.background_dark
theme.titlebar_bg_focus                              = theme.background_dark

-- Icon layout --
theme.layout_floating                                = gears.color.recolor_image(themes_path .. "assets/floating.png",
	theme.foreground)
theme.layout_tile                                    = gears.color.recolor_image(themes_path .. "assets/tile.png",
	theme.foreground)

return theme
