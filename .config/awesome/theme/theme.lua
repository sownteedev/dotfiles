local gears = require("gears")
local theme_assets = require("beautiful.theme_assets")
local xresources = require("beautiful.xresources")
local rnotification = require("ruled.notification")

local theme = {}

theme.font = "Liga SFMono Nerd Font 9"
theme.useless_gap = 5

theme.wall = ""

-- icons --

theme.notification_wifi_icon = "~/.config/awesome/theme/icons/wifi.svg"
theme.battery_icon = "~/.config/awesome/theme/icons/battery.svg"
theme.profile_image = "~/.config/awesome/theme/icons/profile_img.svg"
theme.notification_icon = "~/.config/awesome/theme/icons/bell.svg"
theme.notification_icon_error = "~/.config/awesome/theme/icons/alert.svg"
theme.notification_icon_scrensht = "~/.config/awesome/theme/icons/camera.svg"

-- colors --

theme.background = "#191919"
theme.background_alt = "#292929"
theme.background_urgent = "#393939"
theme.background_urgent1 = "#4c4c4c"
theme.foreground = "#f0f0f0"

theme.green = "#9ec49f"
theme.yellow = "#c4c19e"
theme.blue = "#a5b4cb"
theme.red = "#c49ea0"
theme.orange = "#ceb188"
theme.violet = "#c49ec4"
theme.accent = theme.red

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
