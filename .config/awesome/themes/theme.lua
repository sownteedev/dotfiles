local switcher                                       = require("modules.awesome-switcher")

local theme                                          = {}

theme.font                                           = "Liga SFMono Nerd Font 9"
theme.font1                                          = "Liga SFMono Nerd Font"
theme.icon_font                                      = "Material Design Icons"
theme.useless_gap                                    = 10

-- icons --
theme.notification_wifi_icon                         = "~/.config/awesome/themes/icons/wifi.svg"
theme.battery_icon                                   = "~/.config/awesome/themes/icons/battery.svg"
theme.notification_icon                              = "~/.config/awesome/themes/icons/bell.svg"
theme.notification_icon_error                        = "~/.config/awesome/themes/icons/alert.svg"
theme.notification_icon_scrensht                     = "~/.config/awesome/themes/icons/camera.svg"

-- colors --
theme.background                                     = "#0c0e0f"
theme.background_dark                                = "#0a0b0c"
theme.background_alt                                 = "#141617"
theme.background_urgent                              = "#161819"
theme.background_urgent1                             = "#1f2122"
theme.foreground                                     = "#edeff0"

theme.red                                            = "#df5b61"
theme.green                                          = "#78b892"
theme.blue                                           = "#6791c9"
theme.yellow                                         = "#ecd28b"
theme.orange                                         = "#e89982"
theme.violet                                         = "#c49ec4"
theme.accent                                         = "#a9b1d6"

-- tray --
theme.bg_systray                                     = theme.background_alt
theme.systray_icon_spacing                           = 5

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
theme.tasklist_bg_normal                             = theme.background_urgent1
theme.tasklist_bg_focus                              = theme.accent
theme.tasklist_bg_urgent                             = theme.foreground
theme.tasklist_bg_minimize                           = theme.background_urgent1

-- taglist --
theme.taglist_bg_focus                               = theme.accent
theme.taglist_bg_urgent                              = theme.red
theme.taglist_bg_occupied                            = theme.background_urgent1

-- tooltips --
theme.tooltip_bg                                     = theme.background
theme.tooltip_fg                                     = theme.foreground
theme.tooltip_border_width                           = theme.border_width

-- menu --
theme.menu_submenu                                   = ">  "
theme.menu_height                                    = 32
theme.menu_width                                     = 150
theme.menu_bg_normal                                 = theme.background
theme.menu_fg_normal                                 = theme.foreground
theme.menu_bg_focus                                  = theme.accent
theme.menu_fg_focus                                  = theme.background
theme.menu_border_width                              = theme.border_width
theme.menu_border_color                              = theme.border_color

theme.titlebar_bg_normal                             = theme.background
theme.titlebar_bg_focus                              = theme.background_alt
theme.titlebar_bg_urgent                             = theme.background

return theme
