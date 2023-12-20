local awful = require("awful")

local mainmenu = awful.menu({
	auto_expand = true,
	items = {
		{ "Awesome",
			{
				{ "Restart", awesome.restart },
				{ "Quit",    'awesome-client "awesome.quit()"' },
			}
		},
		{ "Terminal", "alacritty" },
		{ "Files",    "thunar" },
		{ "Apps",
			{
				{ "Chrome",  "google-chrome-stable" },
				{ "Discord", "discord" },
				{ "Spotify", "spotify" },
			}
		},
		{ "Power",
			{
				{ "Shutdown", "poweroff" },
				{ "Reboot",   "reboot" },
				{ "Suspend",  "systemctl suspend" },
				{ "Lock",     "betterlockscreen -l dimblur" },
			}
		},
	}
})

return mainmenu
