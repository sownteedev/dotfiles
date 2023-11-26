local switcher = require("modules.awesome-switcher")
local file = io.open(os.getenv("HOME") .. '/.theme', 'r')
local RICETHEME = file:read('*line')
file:close()

local M = require("themes." .. RICETHEME)

local theme = {}

theme.font = "Liga SFMono Nerd Font 9"
theme.useless_gap = 10

theme.wallpaper = "~/.walls/mountains.jpeg"

-- icons --
theme.notification_wifi_icon = "~/.config/awesome/themes/icons/wifi.svg"
theme.battery_icon = "~/.config/awesome/themes/icons/battery.svg"
theme.profile_image = "~/.config/bspwm/@SownteeNguyen.jpg"
theme.notification_icon = "~/.config/awesome/themes/icons/bell.svg"
theme.notification_icon_error = "~/.config/awesome/themes/icons/alert.svg"
theme.notification_icon_scrensht = "~/.config/awesome/themes/icons/camera.svg"

-- colors --
theme.background = M.background
theme.background_dark = M.background_dark
theme.background_alt = M.background_alt
theme.background_urgent = M.background_urgent
theme.background_urgent1 = M.background_urgent1
theme.foreground = M.foreground

theme.green = M.green
theme.yellow = M.yellow
theme.blue = M.blue
theme.red = M.red
theme.orange = M.orange
theme.violet = M.violet
theme.accent = M.accent

-- tray --
theme.bg_systray = theme.background_alt
theme.systray_icon_spacing = 5

-- Awesome Switcher --
switcher.settings.preview_box = true
switcher.settings.preview_box_bg = "#00000050"
switcher.settings.preview_box_border = "#00000050"
switcher.settings.preview_box_fps = 60
switcher.settings.preview_box_delay = 150
switcher.settings.preview_box_title_font = { "Inter" }
switcher.settings.preview_box_title_font_size_factor = 0.8
switcher.settings.preview_box_title_color = { 255, 255, 255, 1 }

switcher.settings.client_opacity = true
switcher.settings.client_opacity_value = 0.5
switcher.settings.client_opacity_value_in_focus = 0.5
switcher.settings.client_opacity_value_selected = 1

switcher.settings.cycle_raise_client = true

-- borders --
theme.border_width = 0
theme.border_color_normal = theme.background_urgent
theme.border_color_active = theme.accent

-- default vars --
theme.bg_normal = theme.background
theme.fg_normal = theme.foreground

-- tasklist --
theme.tasklist_bg_normal = theme.background_alt
theme.tasklist_bg_focus = theme.accent
theme.tasklist_bg_urgent = theme.foreground
theme.tasklist_bg_minimize = theme.background_alt

theme.task_preview_widget_border_radius = 0
theme.task_preview_widget_bg = "#000000"
theme.task_preview_widget_border_width = 0
theme.task_preview_widget_margin = 0

-- taglist --
theme.taglist_bg_focus = theme.accent
theme.taglist_fg_focus = theme.background
theme.taglist_bg_urgent = theme.red
theme.taglist_fg_urgent = theme.foreground
theme.taglist_bg_occupied = theme.background_urgent1
theme.taglist_fg_occupied = theme.foreground

theme.tag_preview_widget_border_radius = 0
theme.tag_preview_client_border_radius = 0
theme.tag_preview_client_opacity = 1
theme.tag_preview_client_bg = "#000000"
theme.tag_preview_client_border_width = 0
theme.tag_preview_widget_bg = "#00000055"
theme.tag_preview_widget_border_width = 0
theme.tag_preview_widget_margin = 0

-- tooltips --
theme.tooltip_bg = theme.background
theme.tooltip_fg = theme.foreground
theme.tooltip_border_width = theme.border_width

return theme
