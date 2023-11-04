local file = io.open(os.getenv("HOME") .. '/.theme', 'r')
local RICETHEME = file:read('*line')
file:close()

local M = require("themes." .. RICETHEME)

local theme = {}

theme.font = "Liga SFMono Nerd Font 9"
theme.useless_gap = 10

theme.wall = ""

-- icons --

theme.notification_wifi_icon = "~/.config/awesome/themes/icons/wifi.svg"
theme.battery_icon = "~/.config/awesome/themes/icons/battery.svg"
theme.profile_image = "~/.config/bspwm/@SownteeNguyen.jpg"
theme.notification_icon = "~/.config/awesome/themes/icons/bell.svg"
theme.notification_icon_error = "~/.config/awesome/themes/icons/alert.svg"
theme.notification_icon_scrensht = "~/.config/awesome/themes/icons/camera.svg"

-- colors --

theme.background = M.background
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
theme.systray_icon_spacing = 6

-- titlebar --

theme.titlebar_bg_normal = theme.background_alt
theme.titlebar_fg_normal = theme.foreground
theme.titlebar_bg_focus = theme.background_alt
theme.titlebar_fg_focus = theme.foreground
theme.titlebar_bg_urgent = theme.background_alt
theme.titlebar_fg_urgent = theme.foreground

-- borders --

theme.border_width = 0
theme.border_color_normal = theme.background_urgent
theme.border_color_active = theme.accent

-- default vars --

theme.bg_normal = theme.background
theme.fg_normal = theme.foreground

-- notification --

theme.notification_spacing = 20 + theme.border_width * 2

-- tasklist --

theme.tasklist_bg_normal = theme.background_alt
theme.tasklist_bg_focus = theme.accent
theme.tasklist_bg_urgent = theme.foreground
theme.tasklist_bg_minimize = theme.background_alt

-- taglist --

theme.taglist_bg_focus = theme.accent
theme.taglist_fg_focus = theme.background
theme.taglist_bg_urgent = theme.background_urgent1
theme.taglist_fg_urgent = theme.foreground
theme.taglist_bg_occupied = theme.background_urgent
theme.taglist_fg_occupied = theme.foreground
theme.taglist_bg_empty = theme.background_alt
theme.taglist_fg_empty = theme.foreground
theme.taglist_bg_volatile = theme.background_alt
theme.taglist_fg_volatile = theme.foreground

-- bling --

theme.playerctl_player = { "%any" }
theme.playerctl_update_on_activity = true
theme.playerctl_position_update_interval = 1

-- tooltips --

theme.tooltip_bg = theme.background
theme.tooltip_fg = theme.foreground
theme.tooltip_border_width = theme.border_width

return theme
