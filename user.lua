local gfs             = require("gears.filesystem")
local _User           = {}

_User.Name            = "Nguyen Thanh Son"
_User.Username        = "@sownteedev"

_User.Colorscheme     = "dark"
_User.Font            = ""
_User.Sans            = ""

_User.Icon            = "Material Design Icons"
_User.IconName        = "WhiteSur"
_User.Custom_Icon     = {
	{ name = "FFPWA-01JEEVC7KHDEE6E0P8975W60RK", to = "SoundCloud" },
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
	{ name = "com.github.th_ch.youtube_music",   to = "youtube-music-desktop-app" },
	{ name = "GitHub Desktop",                   to = "github-desktop" }
}

_User.Border          = 1
_User.Radius          = 10

_User.Tag             = { "Terminal", "Browser", "Develop", "Media", "Other" }

_User.AutoHideDock    = false

_User.API_KEY_WEATHER = ""
_User.Coordinates     = { "21.0294498", "105.8544441" }

_User.ProfilePicture  = gfs.get_configuration_dir() .. "themes/assets/sownteedev.png"
_User.Wallpaper       = "/home/sowntee/Dotfiles/dotf/.walls/mori.jpg"
_User.Lock            = "/home/sowntee/Dotfiles/dotf/.walls/b.jpg"

_User.SongDefPicture  = gfs.get_configuration_dir() .. "themes/assets/music/artdefault.jpg"

_User.AutoStart       = {
	-- "xrandr --auto --output DP-1 --mode 3840x2160 --primary --auto --right-of eDP-1"
	"xrdb -merge ~/.Xresources",
	"ibus-daemon -drx",
	"/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1",
	"xinput --set-prop 14 'Device Accel Constant Deceleration' 1.5",
	"xsettingsd",
	"libinput-gestures-setup start",
}

return _User
