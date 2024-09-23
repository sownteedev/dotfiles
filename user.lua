local gfs             = require("gears.filesystem")

local _User           = {}

_User.Name            = "Nguyen Thanh Son"
_User.Username        = "@sownteedev"

_User.Colorscheme     = "dark"

_User.PATH_Icon       = "/home/" .. os.getenv("USER") .. "/.icons/WhiteSur/"
_User.Custom_Icon     = {
	{ name = "org.wezfurlong.wezterm",           to = "terminal",            type = "svg" },
	{ name = "Alacritty",                        to = "terminal",            type = "svg" },
	{ name = "St",                               to = "terminal",            type = "svg" },
	{ name = "ncmpcpppad",                       to = "deepin-music-player", type = "svg" },
	{ name = "FFPWA-01J82T1YF1C7RZ9ZD2WV6FZ7GM", to = "SoundCloud",          type = "png" },
	{ name = "wps",                              to = "word",                type = "png" },
	{ name = "et",                               to = "excel",               type = "png" },
	{ name = "wpp",                              to = "powerpoint",          type = "png" }
}

_User.API_KEY_WEATHER = "702cd6f2a4f3450a3673e8bc3078525e"
_User.Coordinates     = { "21.0245", "105.8412" }

_User.PFP             = gfs.get_configuration_dir() .. "themes/assets/sownteedev.png"

_User.LOCK            = os.getenv("HOME") .. "/.walls/lockart.jpg"

_User.SongDefPicture  = gfs.get_configuration_dir() .. "themes/assets/music/artdefault.jpg"

return _User
