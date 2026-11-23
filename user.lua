local gfs             = require("gears.filesystem")
local _User           = {}

_User.Name            = "Nguyen Thanh Son"
_User.Username        = "@sownteedev"

_User.Colorscheme     = "dark"
_User.Font            = "SF Pro Text"
_User.Sans            = "SF Pro Display"

_User.Icon            = "Material Design Icons Desktop"
_User.IconName        = "WhiteSur"
_User.Custom_Icon     = {
}

_User.Border          = 1
_User.Radius          = 10

_User.Tag             = { "Terminal", "Browser", "Develop", "Media", "Other" }

_User.AutoHideDock    = false

_User.API_KEY_WEATHER = ""
_User.Coordinates     = { "21.0294498", "105.8544441" }

_User.ProfilePicture  = gfs.get_configuration_dir() .. "themes/assets/sownteedev.png"
_User.Wallpaper = os.getenv("HOME") .. "/Dotfiles/dotf/.walls/mori.jpg"
_User.Lock = os.getenv("HOME") .. "/Dotfiles/dotf/.walls/b.jpg"
if not gfs.file_readable(_User.Lock) then
	_User.Lock = _User.Wallpaper
end

_User.SongDefPicture  = gfs.get_configuration_dir() .. "themes/assets/music/artdefault.jpg"

_User.AutoStart       = {
	[[pgrep -u "$(id -u)" -x fcitx5 >/dev/null || fcitx5 -d]],
	[[pgrep -u "$(id -u)" -x xsettingsd >/dev/null || xsettingsd]],
	[[if ! pgrep -u "$(id -u)" -f '^(/usr/lib/|/usr/libexec/).*polkit.*authentication-agent' >/dev/null; then
		/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1
	fi]],
	[=[router_desktop="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/9router.desktop"
	if [ -f "$router_desktop" ] && ! pgrep -u "$(id -u)" -f '/9router/cli[.]js([[:space:]]|$)' >/dev/null; then
		gio launch "$router_desktop"
	fi]=],
	[[if [ -n "${XDG_SESSION_ID:-}" ] && ! pgrep -u "$(id -u)" -x xss-lock >/dev/null; then
		xss-lock -l -- "]] .. gfs.get_configuration_dir() .. [[scripts/lock.sh"
	fi]],
}

return _User
