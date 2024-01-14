#!/usr/bin/env bash

# WARNING: THIS IS MY PERSONAL SCRIPT WHEN I REINSTALL ARCH, IT MAY NOT WORK FOR YOU!

pkg_installed() 
{
	local PKG=$1
	if pacman -Qi $PKG &> /dev/null
	then
		return 0
	else
		return 1 
	fi
}

# Update
sudo pacman -Syu --noconfirm

# Git
echo "[*] Installing git ..."
if pkg_installed git
then
	echo "[*] Git already installed, skipping ..."
else
	sudo pacman -S git --noconfirm
	echo "[*] Git Installed."
fi
sleep 2

# Yay
echo "[*] Installing AUR helper(yay) ..."
if pkg_installed yay
then
	echo "[*] Yay already installed, skipping ..."
else
	git clone https://aur.archlinux.org/yay.git && cd yay
	makepkg -si
	cd .. && rm -rf yay
	echo "[*] Yay Installed."
fi
sleep 2

# Clone dotfiles
echo "[*] Cloning dotfiles ..."
git clone htpps://github.com/sownteedev/dotfiles.git ~/dotfiles
echo "[*] Done."

# Font
echo "[*] Copy fonts ..."
mkdir -p ~/.fonts && cp -r ~/dotfiles/.fonts/* ~/.fonts
fc-cache -fv
echo "[*] Done."
sleep 2

# Icon theme && Cursor theme
echo "[*] Copy icons ..."
mkdir -p ~/.icons && cp -r ~/dotfiles/.icons/* ~/.icons
echo "[*] Done."
sleep 2

# Themes
echo "[*] Copy themes ..."
mkdir -p ~/.themes && cp -r ~/dotfiles/.themes/* ~/.themes
echo "[*] Done."
sleep 2

# Wallpaper
echo "[*] Copy wallpaper ..."
mkdir -p ~/.walls && cp -r ~/dotfiles/.walls/* ~/.walls
echo "[*] Done."
sleep 2

# Config
echo "[*] Copy config ..."
if ! [ -d $HOME/.config ];
then
    mkdir -p $HOME/.config
fi
cp -r ~/dotfiles/.config/* ~/.config
echo "[*] Done."
sleep 2

# Local
echo "[*] Copy local ..."
if ! [ -d $HOME/.local ];
then
    mkdir -p $HOME/.local
fi
cp -r ~/dotfiles/.local/* ~/.local
echo "[*] Done."
sleep 2

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
sleep 2

# .Xresources
echo "[*] Copy .Xresources ..."
rm -f ~/.Xresources && cp ~/dotfiles/.Xresources ~/.Xresources
echo "[*] Done."
sleep 2

# Xinitrc
echo "[*] Override .xinitrc ..."
sudo rm -f ~/.xinitrc && sudo cp ~/dotfiles/.local/other/.xinitrc ~/.xinitrc
echo "[*] Done"
sleep 2

#################################################### INSTALL DRIVER AND APPS ####################################################
read -p "[*] Do you want to install driver and dependencies(Recommend Yes)? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then

# Install library
echo "[*] Installing library ..."
sudo pacman -S nodejs npm yarn python python-pip clang jdk-openjdk rustup cargo --noconfirm
echo "[*] Done."
sleep 2

# Audio
echo "[*] Installing audio driver ..."
sudo pacman -S pavucontrol pipewire pipewire-alsa pipewire-audio pulseaudio pulseaudio-bluetooth playerctl pamixer --noconfirm
sudo systemctl enable pipewire pipewire-pulse && systemctl start pipewire pipewire-pulse
echo "[*] Done."
sleep 2

# Brightness
echo "[*] Installing brightness ..."
sudo pacman -S brightnessctl xorg-xbacklight redshift --noconfirm
echo "[*] Done."
sleep 2

# Battery
echo "[*] Installing battery ..."
sudo pacman -S acpi acpid --noconfirm
sudo systemctl enable acpid && systemctl start acpid
echo "[*] Done."
sleep 2

# Network
echo "[*] Installing network ..."
sudo pacman -S netctl networkmanager ifplugd dhcpcd dialog wpa_supplicant wireless_tools --noconfirm
sudo systemctl enable NetworkManager dhcpcd.service
echo "[*] Done."
sleep 2

# Bluetooth
echo "[*] Installing bluetooth driver ..."
sudo pacman -S bluez bluez-utils bluez-tools bluez-libs blueman --noconfirm
sudo systemctl enable bluetooth.service && sudo systemctl start bluetooth.service
sleep 2

# File manager
echo "[*] Installing file manager ..."
sudo pacman -S thunar tumbler ranger ueberzug exa unzip unrar xdg-user-dirs gvfs --noconfirm
echo "[*] Done."
sleep 2

# Monitor and Theme
echo "[*] Installing monitor and theme ..."
sudo pacman -S feh flameshot maim viewnior lxappearance imagemagick neofetch arandr --noconfirm
echo "[*] Done."
sleep 2

# Other
echo "[*] Installing other ..."
sudo pacman -S --noconfirm gnome-keyring libsecret libgnome-keyring seahorse xf86-input-libinput pacman-contrib thefuck wget gpick btop ibus github-cli polkit-gnome xss-lock && yay -S --noconfirm auto-cpufreq picom-ftlabs-git
echo "[*] Done."
sleep 2

else
	echo "[*] Installation driver and dependencies skipped."
fi
######################################## MY CONFIG FOR CUSTOM APPS #######################################

# Spotify
read -p "[*] Do you want to install Spotify and get my custom? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	if pkg_installed spotify
	then
		echo "[*] Installing Spicetify config ..."
		sudo chmod a+wr /opt/spotify
		sudo chmod a+wr /opt/spotify/Apps -R
	else
		echo "[*] Installing Spotify ..."
		yay -S --noconfirm spotify spicetify-cli
	fi
    echo "[*] Done."
else
    echo "[*] Spotify installation skipped."
fi
sleep 2

# Discord
read -p "[*] Do you want to install Discord and get my custom? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing Discord ..."
	yay -S --noconfirm discord betterdiscord-installer
	echo "[*] Done."
else
	echo "[*] Discord installation skipped."
fi
sleep 2

# Firefox
read -p "[*] Do you want to install Firefox and get my custom? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing Firefox ..."
	sudo pacman -S firefox --noconfirm
	echo "[*] Done."
else
	echo "[*] Firefox installation skipped."
fi
cp -r ~/dotfiles/.config/firefox/* ~/.mozilla/firefox/*.default-release/
sleep 2

# Apps for programming
read -p "[*] Do you want to install apps for programming? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    echo "[*] Installing apps for programming ..."
	yay -S --noconfirm visual-studio-code-bin intellij-idea-ultimate-edition intellij-idea-ultimate-edition-jre webstorm webstorm-jre neovim-nightly-bin
    echo "[*] Done."
else
    echo "[*] Apps for programming installation skipped."
fi
sleep 2

# Other apps
read -p "[*] Do you want to install other apps? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing other apps ..."
	sudo pacman -S vlc mpv telegram-desktop --noconfirm && yay -S --noconfirm google-chrome microsoft-edge-stable-bin
else
	echo "[*] Other apps installation skipped."
fi
sleep 2

# Zsh
echo "[*] Installing zsh ..."
if pkg_installed zsh
then
	echo "[*] Zsh already installed, skipping ..."
else
	sudo pacman -S zsh --noconfirm
	echo "[*] Zsh Installed."
fi
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
rm -f ~/.zshrc && touch ~/.zshrc && echo "source ~/.config/zsh/.zshrc" >> ~/.zshrc
echo "[*] Done."
