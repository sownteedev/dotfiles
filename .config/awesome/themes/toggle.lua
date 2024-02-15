local awful = require("awful")

local function backup()
	awful.spawn.easy_async_with_shell([[
		declare -a config_folders=("awesome" "alacritty" "zsh" "ranger" "firefox")
		declare -a data_folders=("BetterDiscord/data/stable" "spicetify/Themes")
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

local function awesome(entry)
	awful.spawn.easy_async_with_shell([[
		sed -i "s/local colorscheme.*/local colorscheme = \"]] .. entry .. [[\"/" ~/.config/awesome/themes/theme.lua &&
	]])
end

local function term(entry)
	awful.spawn.easy_async_with_shell([[
		echo "import = [ '~/.config/alacritty/colors/]] .. entry .. [[.toml' ]" > ~/.config/alacritty/colors.toml &&
	]])
end

local function discord(entry)
	awful.spawn.easy_async_with_shell([[
		cat ~/.config/BetterDiscord/data/stable/themes/]] .. entry .. [[.css > ~/.config/BetterDiscord/data/stable/custom.css &&
	]])
end

local function gtk(entry)
	local color = require("themes.colors." .. entry)
	awful.spawn.easy_async_with_shell([[
		sed -i -e "s/background:.*/background:]] .. color.background .. [[/"\
		       -e "s/background_alt:.*/background_alt:]] .. color.background_alt .. [[/"\
		       -e "s/foreground:.*/foreground:]] .. color.foreground .. [[/"\
		       -e "s/accent:.*/accent:]] .. color.accent .. [[/" ~/.themes/tethemes/gtk-2.0/gtkrc &&
		sed -i -e "s/background .*/background ]] .. color.background .. [[;/"\
			   -e "s/background_alt .*/background_alt ]] .. color.background_alt .. [[;/"\
			   -e "s/background_urgent .*/background_urgent ]] .. color.background_urgent .. [[;/"\
			   -e "s/foreground .*/foreground ]] .. color.foreground .. [[;/"\
			   -e "s/accent .*/accent ]] .. color.accent .. [[;/" ~/.themes/tethemes/gtk-3.0/colors.css &&
	]])
end

local function firefox(entry)
	local color = require("themes.colors." .. entry)
	awful.spawn.easy_async_with_shell([[
		sed -i -e "s/background: .*/background: ]] .. color.background .. [[ !important;/"\
			   -e "s/background-color: .*/background-color: ]] .. color.background .. [[ !important;/"\
			   -e "s/color: .*/color: ]] .. color.background .. [[ !important;/" ~/.config/firefox/chrome/userContent.css &&
		sed -i -e "s/--uc-base-colour: .*/--uc-base-colour: ]] .. color.background_alt .. [[;/"\
			   -e "s/--uc-highlight-colour: .*/--uc-highlight-colour: ]] .. color.background .. [[;/"\
			   -e "s/--uc-inverted-colour: .*/--uc-inverted-colour: ]] .. color.foreground .. [[;/"\
			   -e "s/--uc-identity-colour-red: .*/--uc-identity-colour-red: ]] .. color.red .. [[;/"\
			   -e "s/--uc-identity-colour-green: .*/--uc-identity-colour-green: ]] .. color.green .. [[;/"\
			   -e "s/--uc-identity-colour-blue: .*/--uc-identity-colour-blue: ]] .. color.blue .. [[;/"\
			   -e "s/--uc-identity-colour-yellow: .*/--uc-identity-colour-yellow: ]] .. color.yellow .. [[;/"\
			   -e "s/--uc-identity-colour-orange: .*/--uc-identity-colour-orange: ]] .. color.orange .. [[;/" ~/.config/firefox/chrome/includes/cascade-colours.css &&
		rm -r ~/.mozilla/firefox/*.default-release/chrome/* && cp -r ~/.config/firefox/chrome/* ~/.mozilla/firefox/*.default-release/chrome/ &&
	]])
end

function applyTheme(theme)
	term(theme)
	awesome(theme)
	discord(theme)
	gtk(theme)
	firefox(theme)
	backup()
	awful.spawn.with_shell([[
		spicetify config color_scheme ]] .. theme .. [[ && spicetify apply &&
	]])
	awful.spawn.with_shell("ls -1 /run/user/1000/ | grep nvim ", function(stdout)
		for line in stdout:gmatch("[^\n]+") do
			awful.spawn.with_shell(
				[[
				nvim --server /run/user/1000/]]
					.. line
					.. [[ --remote-send ':lua require("tevim.themes.pick").setTheme("]]
					.. theme
					.. [[")<CR>']]
			)
		end
	end)
	awful.spawn.with_shell([[
		awesome-client 'awesome.restart()' &&
	]])
end
