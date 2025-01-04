local awful = require("awful")
local gears = require("gears")

local function awesomewm(theme)
	awful.spawn.with_shell([[
		sed -i "s/_User.Colorscheme.*/_User.Colorscheme     = \"]] .. theme .. [[\"/" ~/.config/awesome/user.lua &&
	]])
	awful.spawn.with_shell("awesome-client 'awesome.restart()'")
end

local function term(theme)
	awful.spawn.with_shell([[
		sed -i "s#~/.config/alacritty/colors/.*\.toml#~/.config/alacritty/colors/"]] ..
		theme .. [[".toml#" ~/.config/alacritty/alacritty.toml &&
	]])
end

local function gtk(theme)
	awful.spawn.with_shell([[
		sed -i "s/gtk-theme-name=.*/gtk-theme-name=]] .. theme .. [[/" ~/.config/gtk-3.0/settings.ini &&
		sed -i 's/gtk-theme-name=.*/gtk-theme-name="]] .. theme .. [["/' ~/.gtkrc-2.0 &&
		sed -i 's/Net\/ThemeName.*/Net\/ThemeName "]] .. theme .. [["/' ~/.xsettingsd &&
	]])
end

local function spotify(theme)
	local scheme = theme == "light" and "catppuccin-latte" or "Lunar"
	awful.spawn.with_shell([[
		spicetify config color_scheme ]] ..
		scheme .. [[ inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1 && spicetify apply &&
	]])
end

local function for_signal(theme)
	local status = theme == "dark" and 1 or 0
	local status1 = theme == "dark" and "true" or "false"
	awful.spawn.easy_async_with_shell(
		string.format("echo %s > %s", status1, gears.filesystem.get_cache_dir() .. "dark"),
		function()
			awesome.emit_signal("signal::darkmode", status)
		end)
end

function applyTheme(theme)
	term(theme)
	-- gtk(theme)
	spotify(theme)
	awesomewm(theme)
	for_signal(theme)
	-- awful.spawn.easy_async("xsettingsd")

	-- awful.spawn.easy_async_with_shell("ls -1 /run/user/1000/ | grep nvim", function(stdout)
	-- 	local scheme = theme == "light" and "one_light" or "phocus"
	-- 	for line in stdout:gmatch("[^\n]+") do
	-- 		awful.spawn.easy_async_with_shell(
	-- 			[[
	-- 			nvim --server /run/user/1000/]]
	-- 			.. line
	-- 			.. [[ --remote-send ':lua require("tevim.themes.pick").setTheme("]]
	-- 			.. scheme
	-- 			.. [[")<CR>']]
	-- 		)
	-- 	end
	-- end)
end

function toggle_darkmode()
	local scheme = _User.Colorscheme == "dark" and "light" or "dark"
	applyTheme(scheme)
end

awful.spawn.easy_async_with_shell("cat " .. gears.filesystem.get_cache_dir() .. 'dark', function(status)
	status = status:match("true")
	awesome.emit_signal("signal::darkmode", status)
end)
