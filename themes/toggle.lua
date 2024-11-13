local awful = require("awful")

function backup()
	awful.spawn.with_shell([[
		declare -a config_folders=("alacritty" "zsh" "ranger" "gtk-3.0" "picom")
		declare -a data_folders=("nvim/lua/custom" "spicetify/Themes")
		declare -a dot_folders=("fonts" "icons" "themes" "walls" "root") &&

		rm -rf ~/dotf/{.config,.fonts,.icons,.themes,.walls,.root,.local}
		mkdir -p ~/dotf/{.config,.fonts,.icons,.themes,.walls,.root,.local}
		
		for folder in "${dot_folders[@]}"; do
			cp -r ~/."$folder"/* ~/dotf/.${folder}/
		done

		for folder in "${config_folders[@]}"; do
			cp -r ~/.config/"$folder" ~/dotf/.config/
		done
		cp ~/.config/libinput-gestures.conf ~/dotf/.config/ &&
		for folder in "${data_folders[@]}"; do
			mkdir -p ~/dotf/.config/"$folder"
			cp -r ~/.config/"$folder"/* ~/dotf/.config/"$folder"
		done
		
		cp -r ~/.local/other/ ~/dotf/.local/ && cp -r ~/.local/bin/ ~/dotf/.local/ && mkdir -p ~/dotf/.local/share/nemo/ && cp -r ~/.local/share/nemo/actions/ ~/dotf/.local/share/nemo/
		cp ~/.config/Caprine/custom.css ~/dotf/.local/other/customcaprine.css &&
		cp ~/.config/spicetify/Themes/Tetify/user.css ~/dotf/.local/other/customspotify.css &&
		
		rm -f ~/dotf/.gtkrc-2.0 && cp ~/.gtkrc-2.0 ~/dotf/
		rm -f ~/dotf/.Xresources && cp ~/.Xresources ~/dotf/
		rm -f ~/dotf/.xinitrc && cp ~/.xinitrc ~/dotf/
		rm -f ~/dotf/.xsettingsd && cp ~/.xsettingsd ~/dotf/
	]])
end

local function awesome(theme)
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
	theme = string.upper(string.sub(theme, 0, 1)) .. string.sub(theme, 2)
	awful.spawn.with_shell([[
		sed -i "s/gtk-theme-name=.*/gtk-theme-name=WhiteSur-]] .. theme .. [[/" ~/.config/gtk-3.0/settings.ini &&
		sed -i 's/gtk-theme-name=.*/gtk-theme-name="WhiteSur-]] .. theme .. [["/' ~/.gtkrc-2.0 &&
		sed -i 's/Net\/ThemeName.*/Net\/ThemeName "WhiteSur-]] .. theme .. [["/' ~/.xsettingsd &&
	]])
end

local function spotify(theme)
	awful.spawn.with_shell([[
		spicetify config color_scheme ]] .. theme .. [[ && spicetify apply &&
	]])
end

function applyTheme(theme)
	term(theme)
	-- gtk(theme)
	-- spotify(theme)
	awesome(theme)
	awful.spawn.easy_async("xsettingsd")
	-- awful.spawn.easy_async_with_shell("ls -1 /run/user/1000/ | grep nvim", function(stdout)
	-- 	for line in stdout:gmatch("[^\n]+") do
	-- 		awful.spawn.easy_async_with_shell(
	-- 			[[
	-- 			nvim --server /run/user/1000/]]
	-- 			.. line
	-- 			.. [[ --remote-send ':lua require("tevim.themes.pick").setTheme("]]
	-- 			.. theme
	-- 			.. [[")<CR>']]
	-- 		)
	-- 	end
	-- end)
end

function darkmode()

end
