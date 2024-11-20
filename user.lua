local gfs             = require("gears.filesystem")

local _User           = {}

_User.Name            = "Nguyen Thanh Son"
_User.Username        = "@sownteedev"

_User.Colorscheme     = "dark"
_User.Font            = "SF Pro Display 12"
_User.Sans            = "SF Pro Display"

_User.Icon            = "Material Design Icons"
_User.IconName        = "WhiteSur"
_User.Custom_Icon     = {
	{ name = "FFPWA-01J9K7824YX3HRKD9K1ZG34PZZ", to = "SoundCloud" },
	{ name = "Alacritty",                        to = "terminal" },
	{ name = "wps",                              to = "Word" },
	{ name = "et",                               to = "Excel" },
	{ name = "wpp",                              to = "PowerPoint" },
	-- { name = "wps",                              to = "wps-office2019-wpsmain" },
	-- { name = "et",                               to = "wps-office2019-etmain" },
	-- { name = "wpp",                              to = "wps-office2019-wppmain" },
	{ name = "pdf",                              to = "wps-office2019-pdfmain" },
	{ name = "jetbrains-studio",                 to = "android-studio" },
	{ name = "MongoDB Compass",                  to = "mongodb-compass" },
	{ name = "Mysql-workbench-bin",              to = "mysql-workbench" },
}

_User.Border          = 1
_User.Radius          = 10

_User.Tag             = { "Terminal", "Browser", "Develop", "Media", "Other" }

_User.AutoHideDock    = false

_User.API_KEY_WEATHER = ""
_User.Coordinates     = { "21.0245", "105.8412" }

_User.ProfilePicture  = gfs.get_configuration_dir() .. "themes/assets/sownteedev.png"
_User.Wallpaper       = "/usr/share/backgrounds/budgie/default.jpg"
_User.Lock            = "/home/sowntee/.walls/a.jpg"

_User.SongDefPicture  = gfs.get_configuration_dir() .. "themes/assets/music/artdefault.jpg"

_User.AutoStart       = {
	-- "xrandr --auto --output DP-1 --mode 3840x2160 --primary --auto --right-of eDP-1"
	"ibus-daemon -drx",
	"xsettingsd",
	"libinput-gestures-setup start",
}

return _User
