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
	{ name = "org.wezfurlong.wezterm",           to = "terminal" },
	{ name = "Alacritty",                        to = "terminal" },
	{ name = "St",                               to = "terminal" },
	{ name = "ncmpcpppad",                       to = "deepin-music-player" },
	{ name = "FFPWA-01J9K7824YX3HRKD9K1ZG34PZZ", to = "SoundCloud" },
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
_User.Radius          = 15

_User.AutoHideDock    = false

_User.API_KEY_WEATHER = "0187188eefff4d3ba6100addd927a24a"
_User.Coordinates     = { "21.0245", "105.8412" }

_User.ProfilePicture  = gfs.get_configuration_dir() .. "themes/assets/sownteedev.png"
_User.Wallpaper       = "/home/sowntee/.walls/a.jpg"
_User.Lock            = "/home/sowntee/.walls/a.jpg"

_User.SongDefPicture  = gfs.get_configuration_dir() .. "themes/assets/music/artdefault.jpg"

_User.AutoStart       = {
	-- "xrandr --auto --output DP-1 --mode 3840x2160 --primary --auto --right-of eDP-1"
	"ibus-daemon -drx",
	"pamixer",
	"pactl",
	"xss-lock -l awesome-client 'awesome.emit_signal(\"toggle::lock\")'",
	"libinput-gestures-setup start",
}

return _User
