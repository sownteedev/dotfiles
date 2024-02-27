#!/usr/bin/env bash

# WARNING: THIS IS MY PERSONAL SCRIPT WHEN I REINSTALL ARCH, IT MAY NOT WORK FOR YOU!

pkg_installed() {
	local PKG=$1
	if pacman -Qi $PKG &>/dev/null; then
		return 0
	else
		return 1
	fi
}

# Update
sudo pacman -Syu --noconfirm
sleep 5 && clear

# Yay
echo "[*] Installing AUR helper(yay) ..."
if pkg_installed yay; then
	echo "[*] Yay already installed, skipping ..."
else
	git clone https://aur.archlinux.org/yay.git && cd yay
	makepkg -si
	cd .. && rm -rf yay
	echo "[*] Yay Installed."
fi
sleep 5 && clear

# Font
sudo pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji --noconfirm
echo "[*] Copy fonts ..."
mkdir -p ~/.fonts && cp -r ~/dotfiles/.fonts/* ~/.fonts
fc-cache -fv
echo "[*] Done."
sleep 5 && clear

# Icon theme && Cursor theme
echo "[*] Copy icons ..."
mkdir -p ~/.icons && cp -r ~/dotfiles/.icons/* ~/.icons
echo "[*] Done."
sleep 5 && clear

# Themes
echo "[*] Copy themes ..."
mkdir -p ~/.themes && cp -r ~/dotfiles/.themes/* ~/.themes
echo "[*] Done."
sleep 5 && clear

# Wallpaper
echo "[*] Copy wallpaper ..."
mkdir -p ~/.walls && cp -r ~/dotfiles/.walls/* ~/.walls
echo "[*] Done."
sleep 5 && clear

# Config
echo "[*] Copy config ..."
if ! [ -d $HOME/.config ]; then
	mkdir -p $HOME/.config
fi
cp -r ~/dotfiles/.config/* ~/.config
echo "[*] Done."
sleep 5 && clear

# Local
echo "[*] Copy local ..."
if ! [ -d $HOME/.local ]; then
	mkdir -p $HOME/.local
fi
cp -r ~/dotfiles/.local/* ~/.local
echo "[*] Done."
sleep 5 && clear

# Enable touchpad
echo "[*] Enable touchpad for laptop ..."
read -p "[*] Do you want? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	sudo touch /etc/X11/xorg.conf.d/30-touchpad.conf
	sudo cp ~/dotfiles/.local/other/30-touchpad.conf /etc/X11/xorg.conf.d/30-touchpad.conf
	echo "[*] Done."
else
	echo "[*] Skipped."
fi
sleep 5 && clear

# .Xresources
echo "[*] Copy .Xresources ..."
rm -f ~/.Xresources && cp ~/dotfiles/.Xresources ~/.Xresources
echo "[*] Done."
sleep 5 && clear

# Xinitrc
echo "[*] Override .xinitrc ..."
sudo rm -f ~/.xinitrc && sudo cp ~/dotfiles/.xinitrc ~/.xinitrc
echo "[*] Done"
sleep 5 && clear

#################################################### INSTALL DRIVER AND APPS ####################################################
read -p "[*] Do you want to install driver and dependencies(Recommend Yes)? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	# Install library
	echo "[*] Installing library ..."
	sudo pacman -S nodejs npm yarn python python-pip clang jdk-openjdk rustup cargo --noconfirm
	echo "[*] Done."
	sleep 5 && clear

	# Audio
	echo "[*] Installing audio & mic driver ..."
	sudo pacman -S pavucontrol pipewire pipewire-alsa pipewire-audio pipewire-pulse alsa-ucm-conf sof-firmware playerctl pamixer --noconfirm
	systemctl --user enable pipewire pipewire-pulse wireplumber
	echo "[*] Done."
	sleep 5 && clear

	# Brightness
	echo "[*] Installing brightness ..."
	sudo pacman -S brightnessctl xorg-xbacklight redshift --noconfirm
	echo "[*] Done."
	sleep 5 && clear

	# Battery
	echo "[*] Installing battery ..."
	sudo pacman -S acpi acpid --noconfirm
	sudo systemctl enable acpid
	echo "[*] Done."
	sleep 5 && clear

	# Network
	echo "[*] Installing network ..."
	sudo pacman -S netctl networkmanager ifplugd dhcpcd dialog wpa_supplicant wireless_tools --noconfirm
	sudo systemctl enable NetworkManager dhcpcd.service
	echo "[*] Done."
	sleep 5 && clear

	# Bluetooth
	echo "[*] Installing bluetooth driver ..."
	sudo pacman -S bluez bluez-utils bluez-tools bluez-libs blueman --noconfirm
	sudo systemctl enable bluetooth.service
	sleep 5 && clear

	# File manager
	echo "[*] Installing file manager ..."
	sudo pacman -S thunar tumbler ranger ueberzug exa unzip unrar xdg-user-dirs gvfs --noconfirm
	echo "[*] Done."
	sleep 5 && clear

	# Monitor and Theme
	echo "[*] Installing monitor and theme ..."
	sudo pacman -S feh flameshot maim viewnior lxappearance imagemagick neofetch arandr --noconfirm
	echo "[*] Done."
	sleep 5 && clear

	# Other
	echo "[*] Installing other ..."
	sudo pacman -S --noconfirm gnome-keyring polkit-gnome libgnome-keyring libsecret seahorse xf86-input-libinput pacman-contrib gpick btop ibus github-cli xss-lock && yay -S --noconfirm auto-cpufreq picom-ftlabs-git rofi
	echo "[*] Done."
	sleep 5 && clear

else
	echo "[*] Installation driver and dependencies skipped."
fi

######################################## MY CONFIG FOR CUSTOM APPS #######################################

# Spotify
read -p "[*] Do you want to install Spotify and get my custom? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	if pkg_installed spotify; then
		echo "[*] Spotify installation skipped."
	else
		echo "[*] Installing Spotify ..."
		yay -S --noconfirm spotify
	fi
	yay -S --noconfirm spicetify-cli
	sudo chmod a+wr /opt/spotify
	sudo chmod a+wr /opt/spotify/Apps -R
	echo "[*] Done."
else
	echo "[*] Spotify installation skipped."
fi
sleep 5 && clear

# Discord
read -p "[*] Do you want to install Discord and get my custom? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing Discord ..."
	yay -S --noconfirm discord betterdiscord-installer
	echo "[*] Done."
else
	echo "[*] Discord installation skipped."
fi
sleep 5 && clear

# Firefox
read -p "[*] Do you want to install Firefox and get my custom? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing Firefox ..."
	sudo pacman -S firefox --noconfirm
	firefox &
	sleep 3
	pkill firefox
	echo "[*] Done."
else
	echo "[*] Firefox installation skipped."
fi
cp -r ~/dotfiles/.config/firefox/* ~/.mozilla/firefox/*.default-release/
sleep 5 && clear

# Install TeVim
read -p "[*] Do you want to install TeVim? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing TeVim ..."
	yay -S --noconfirm neovim-nightly-bin lazygit xclip xsel fzf ripgrep
	git clone https://github.com/sownteedev/TeVim.git --depth 1 ~/.config/nvim
	echo "[*] Done."
else
	echo "[*] TeVim installation skipped."
fi
sleep 5 && clear

# Fix Driver audio (for me)
read -p "[*] Do you want to fix audio driver(Recommend No, because it is for me)? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	mkdir -p ~/old-sof-backup
	sudo mv /lib/firmware/intel/sof* ~/old-sof-backup
	sudo mv /usr/local/bin/sof-* ~/old-sof-backup

	git clone https://github.com/thesofproject/sof-bin.git && cd sof-bin/v2.1.x
	sudo rsync -a sof*v2.1.1 /lib/firmware/intel/
	sudo ln -s sof-v2.1.1 /lib/firmware/intel/sof
	sudo ln -s sof-tplg-v2.1.1 /lib/firmware/intel/sof-tplg
	sudo rsync tools-v2.1.1/* /usr/local/bin

	git clone https://github.com/thesofproject/alsa-ucm-conf.git && cd alsa-ucm-conf
	sudo rm -r /usr/share/alsa/ucm
	sudo mv ./ucm /usr/share/alsa
else
	echo "[*] Fix audio driver skipped."
fi

# Zsh
echo "[*] Installing zsh ..."
if pkg_installed zsh; then
	echo "[*] Zsh already installed, skipping ..."
else
	sudo pacman -S zsh --noconfirm
	echo "[*] Zsh Installed."
fi
rm -f ~/.zshrc && touch ~/.zshrc && echo "source ~/.config/zsh/.zshrc" >>~/.zshrc
sleep 5 && clear
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo "[*] Done."
