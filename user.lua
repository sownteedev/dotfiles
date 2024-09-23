local gfs             = require("gears.filesystem")

local _User           = {}

_User.Name            = "Nguyen Thanh Son"
_User.Username        = "@sownteedev"

_User.Colorscheme     = "dark"

_User.PATH_Icon       = "/home/" .. os.getenv("USER") .. "/.icons/WhiteSur/"
_User.Custom_Icon     = {
	{ name = "org.wezfurlong.wezterm",           to = "terminal" },
	{ name = "Alacritty",                        to = "terminal" },
	{ name = "St",                               to = "terminal" },
	{ name = "ncmpcpppad",                       to = "deepin-music-player" },
	{ name = "FFPWA-01J82T1YF1C7RZ9ZD2WV6FZ7GM", to = "SoundCloud" },
	{ name = "wps",                              to = "Word" },
	{ name = "et",                               to = "Excel" },
	{ name = "wpp",                              to = "PowerPoint" },
	-- { name = "wps",                              to = "wps-office2019-wpsmain" },
	-- { name = "et",                               to = "wps-office2019-etmain" },
	-- { name = "wpp",                              to = "wps-office2019-wppmain" },
	{ name = "pdf",                              to = "wps-office2019-pdfmain" },
}

_User.API_KEY_WEATHER = "702cd6f2a4f3450a3673e8bc3078525e"
_User.Coordinates     = { "21.0245", "105.8412" }

_User.PFP             = gfs.get_configuration_dir() .. "themes/assets/sownteedev.png"

_User.LOCK            = os.getenv("HOME") .. "/.walls/lockart.jpg"

_User.SongDefPicture  = gfs.get_configuration_dir() .. "themes/assets/music/artdefault.jpg"

return _User
