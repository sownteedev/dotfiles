local awful = require("awful")
local helpers = require("helpers")

local function backup()
	awful.spawn.easy_async_with_shell([[
		declare -a config_folders=("awesome" "alacritty" "zsh" "ranger" "firefox" "gtk-3.0")
		declare -a data_folders=("BetterDiscord/data/stable" "spicetify/Themes" "nvim/lua/custom")
		declare -a dot_folders=("fonts" "icons" "themes" "walls") &&

		rm -rf ~/dotfiles/{.config,.fonts,.icons,.themes,.walls,.local}
		mkdir -p ~/dotfiles/{.config,.fonts,.icons,.themes,.walls,.local}
		
		for folder in "${dot_folders[@]}"; do
			cp -r ~/."$folder"/* ~/dotfiles/.${folder}/
		done

		for folder in "${config_folders[@]}"; do
			cp -r ~/.config/"$folder" ~/dotfiles/.config/
		done

		for folder in "${data_folders[@]}"; do
			mkdir -p ~/dotfiles/.config/"$folder"
			cp -r ~/.config/"$folder"/* ~/dotfiles/.config/"$folder"
		done

		cp -r ~/.local/other/ ~/dotfiles/.local/ && cp -r ~/.local/bin/ ~/dotfiles/.local/
		rm -f ~/dotfiles/.Xresources && cp ~/.Xresources ~/dotfiles/
		rm -f ~/dotfiles/.xinitrc && cp ~/.xinitrc ~/dotfiles/
	]])
end

local function awesome(theme)
	awful.spawn.easy_async_with_shell([[
		sed -i "s/local colorscheme.*/local colorscheme = \"]] .. theme .. [[\"/" ~/.config/awesome/themes/theme.lua &&
	]])
end

local function rofi(theme)
	local color = require("themes.colors." .. theme)
	awful.spawn.easy_async_with_shell([[
		sed -i -e "s/background:.*/background:]] .. color.darker .. [[;/"\
		       -e "s/lighter:.*/lighter:]] .. color.lighter .. [[;/"\
		       -e "s/foreground:.*/foreground:]] .. color.foreground .. [[;/"\
			   -e "s/darker:.*/darker:]] .. color.background .. [[;/" ~/.config/awesome/signals/scripts/Wifi/Wifi.rasi &&
		sed -i -e "s/background:.*/background:]] .. color.darker .. [[;/"\
		       -e "s/lighter:.*/lighter:]] .. color.lighter .. [[;/"\
		       -e "s/foreground:.*/foreground:]] .. color.foreground .. [[;/"\
			   -e "s/darker:.*/darker:]] ..
		color.background .. [[;/" ~/.config/awesome/signals/scripts/Bluetooth/Bluetooth.rasi &&
	]])
end

local function term(theme)
	local color = require("themes.colors." .. theme)
	awful.spawn.easy_async_with_shell([[
		sed -i "s#~/.config/alacritty/colors/.*\.toml#~/.config/alacritty/colors/"]] ..
		theme .. [[".toml#" ~/.config/alacritty/alacritty.toml &&
		sed -i "s/bgl=.*/bgl=]] .. color.lighter .. [[/" ~/.config/zsh/theme.zsh &&
	]])
end

local function discord(theme)
	awful.spawn.easy_async_with_shell([[
		cat ~/.config/BetterDiscord/data/stable/themes/]] ..
		theme .. [[.css > ~/.config/BetterDiscord/data/stable/custom.css &&
	]])
end

local function gtk(theme)
	local color = require("themes.colors." .. theme)
	awful.spawn.easy_async_with_shell([[
		sed -i -e "s/background .*/background ]] .. color.background .. [[;/"\
			   -e "s/lighter .*/lighter ]] .. color.lighter .. [[;/"\
			   -e "s/lighter1 .*/lighter1 ]] .. color.lighter1 .. [[;/"\
			   -e "s/foreground .*/foreground ]] .. color.foreground .. [[;/" ~/.themes/tethemes/gtk-3.0/colors.css &&
	]])
end

local function firefox(theme)
	local color = require("themes.colors." .. theme)
	awful.spawn.easy_async_with_shell([[
		sed -i -e "s/background: .*/background: ]] .. color.background .. [[ !important;/"\
			   -e "s/background-color: .*/background-color: ]] .. color.background .. [[ !important;/"\
			   -e "s/color: .*/color: ]] .. color.background .. [[ !important;/" ~/.config/firefox/chrome/userContent.css &&
		sed -i -e "s/--uc-base-colour: .*/--uc-base-colour: ]] .. color.lighter .. [[;/"\
			   -e "s/--uc-highlight-colour: .*/--uc-highlight-colour: ]] .. color.background .. [[;/"\
			   -e "s/--uc-inverted-colour: .*/--uc-inverted-colour: ]] .. color.foreground .. [[;/"\
			   -e "s/--uc-identity-colour-red: .*/--uc-identity-colour-red: ]] .. color.red .. [[;/"\
			   -e "s/--uc-identity-colour-green: .*/--uc-identity-colour-green: ]] .. color.green .. [[;/"\
			   -e "s/--uc-identity-colour-blue: .*/--uc-identity-colour-blue: ]] .. color.blue .. [[;/"\
			   -e "s/--uc-identity-colour-yellow: .*/--uc-identity-colour-yellow: ]] .. helpers.mix(
		color.red,
		color.green,
		0.5
	) .. [[;/"\
			   -e "s/--uc-identity-colour-orange: .*/--uc-identity-colour-orange: ]] .. helpers.mix(
		color.red,
		helpers.mix(color.red, color.green, 0.5),
		0.5
	) .. [[;/" ~/.config/firefox/chrome/includes/cascade-colours.css &&
		rm -r ~/.mozilla/firefox/*.default-release/chrome/* && cp -r ~/.config/firefox/chrome/* ~/.mozilla/firefox/*.default-release/chrome/ &&
	]])
end

local function spotify(theme)
	awful.spawn.with_shell([[
		spicetify config color_scheme ]] .. theme .. [[ && spicetify apply &&
	]])
end
function applyTheme(theme)
	term(theme)
	awesome(theme)
	rofi(theme)
	discord(theme)
	gtk(theme)
	firefox(theme)
	spotify(theme)
	backup()
	awful.spawn.easy_async_with_shell("ls -1 /run/user/1000/ | grep nvim", function(stdout)
		for line in stdout:gmatch("[^\n]+") do
			awful.spawn.easy_async_with_shell(
				[[
				nvim --server /run/user/1000/]]
				.. line
				.. [[ --remote-send ':lua require("tevim.themes.pick").setTheme("]]
				.. theme
				.. [[")<CR>']]
			)
		end
		-- awful.spawn.easy_async_with_shell("awesome-client 'awesome.restart()'")
	end)
end

function darkmode()
	awful.spawn.easy_async_with_shell("bash -c 'cat ~/.cache/darkmode'", function(status)
		status = status:gsub("\n", "")
		if status == "true" then
			awful.spawn.with_shell(
				[[bash -c "awesome-client 'applyTheme(\"yoru\")' && echo false > ~/.cache/darkmode"]])
		else
			awful.spawn.with_shell(
				[[bash -c "awesome-client 'applyTheme(\"one_light\")' && echo true > ~/.cache/darkmode"]])
		end
	end)
end
