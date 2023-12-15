#!/usr/bin/env bash

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

# Git
echo "[*] Installing git ..."
if pkg_installed git
then
	echo "[*] Git already installed, skipping ..."
else
	sudo pacman -S git --noconfirm
	echo "[*] Git Installed."
fi
sleep 1

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
sleep 1

# Clone dotfiles
echo "[*] Cloning dotfiles ..."
git clone htpps://github.com/sownteedev/dotfiles.git ~/dotfiles
echo "[*] Done."

# Font
echo "[*] Installing font ..."
yay -S --noconfirm noto-fonts noto-fonts-cjk ttf-joypixels # ttf-material-icons-git
echo "[*] Copy fonts ..."
mkdir -p ~/.fonts && cp -r ~/dotfiles/.fonts/* ~/.fonts
fc-cache -fv
echo "[*] Done."
sleep 1

# Icon theme
echo "[*] Installing Reversal dark icons ..."
git clone --depth 1 https://github.com/yeyushengfan258/Reversal-icon-theme.git
cd Reversal-icon-theme && chmod +x install.sh
./install.sh -black && reset
echo "[*] Done."
sleep 1

# Icon
echo "[*] Copy icons ..."
mkdir -p ~/.icons && cp -r ~/dotfiles/.icons/* ~/.icons
echo "[*] Done."
sleep 1

# Themes
echo "[*] Copy themes ..."
mkdir -p ~/.themes && cp -r ~/dotfiles/.themes/* ~/.themes
echo "[*] Done."
sleep 1

# Wallpaper
echo "[*] Copy wallpaper ..."
mkdir -p ~/.walls && cp -r ~/dotfiles/.walls/* ~/.walls
echo "[*] Done."
sleep 1

# Config
echo "[*] Copy config ..."
if ! [ -d $HOME/.config ];
then
    mkdir -p $HOME/.config
fi
cp -r ~/dotfiles/.config/* ~/.config
echo "[*] Done."
sleep 1

# Local
echo "[*] Copy local ..."
if ! [ -d $HOME/.local ];
then
    mkdir -p $HOME/.local
fi
cp -r ~/dotfiles/.local/* ~/.local
echo "[*] Done."
sleep 1

# .Xresources
echo "[*] Copy .Xresources ..."
cp ~/dotfiles/.Xresources ~/.Xresources
echo "[*] Done."
sleep 1

# Enable touchpad
echo "[*] Enable touchpad ..."
sudo touch /etc/X11/xorg.conf.d/30-touchpad.conf
sudo cp ~/dotfiles/.local/other/30-touchpad.conf /etc/X11/xorg.conf.d/30-touchpad.conf
echo "[*] Done."
sleep 1

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
rm ~/.zshrc && touch ~/.zshrc && echo "source ~/.config/zsh/.zshrc" >> ~/.zshrc
echo "[*] Done."
sleep 1

# Install dunst && rofi
echo "[*] Installing dunst, rofi, picom ..."
sudo pacman -S dunst rofi --noconfirm && yay -S --noconfirm picom-ftlabs-git
echo "[*] Done."
sleep 1

# Install library
echo "[*] Installing library ..."
sudo pacman -S nodejs npm yarn python python-pip clang jdk-openjdk rustup cargo --noconfirm
echo "[*] Done."
sleep 1

# Audio
echo "[*] Installing audio driver ..."
sudo pacman -S pavucontrol pipewire pipewire-alsa pipewire-audio pulseaudio pulseaudio-bluetooth playerctl pamixer mpd mpc ncmpcpp --noconfirm
sudo systemctl enable pipewire pipewire-pulse && systemctl --user start pipewire pipewire-pulse
sudo systemctl enable mpd.service && systemctl --user start mpd.service
echo "[*] Done."
sleep 1

# Brightness
echo "[*] Installing brightness ..."
sudo pacman -S brightnessctl xorg-xbacklight --noconfirm
echo "[*] Done."
sleep 1

# Battery
echo "[*] Installing battery ..."
sudo pacman -S acpi acpid --noconfirm
sudo systemctl enable acpid && systemctl start acpid
echo "[*] Done."
sleep 1

# Network
echo "[*] Installing network ..."
sudo pacman -S netctl networkmanager ifplugd dhcpcd dialog wpa_supplicant wireless_tools
sudo systemctl enable NetworkManager dhcpcd.service
echo "[*] Done."
sleep 1

# Bluetooth
echo "[*] Installing bluetooth driver ..."
sudo pacman -S bluez bluez-utils bluez-tools bluez-libs blueman --noconfirm
sudo systemctl enable bluetooth.service && sudo systemctl start bluetooth.service
sleep 1

# File manager
echo "[*] Installing file manager ..."
sudo pacman -S thunar tumbler nemo ranger ueberzug exa unzip unrar xdg-user-dirs --noconfirm && yay -S --noconfirm highlight
echo "[*] Done."
sleep 1

# Monitor and Theme
echo "[*] Installing monitor and theme ..."
sudo pacman -S feh flameshot maim viewnior lxappearance neofetch --noconfirm && yay -S --noconfirm imagemagick
echo "[*] Done."
sleep 1


################ APPS ################

# Spotify
read -p "[*] Do you want to install Spotify and its config? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    echo "[*] Installing Spotify ..."
    yay -S --noconfirm spotify spicetify-cli
    echo "[*] Installing Spicetify config ..."
    sudo chmod a+wr /opt/spotify
    sudo chmod a+wr /opt/spotify/Apps -R
    # spicetify config current_theme Snow
    # spicetify backup apply # Manually as needs login!
    echo "[*] Done."
else
    echo "[*] Spotify installation skipped."
fi
sleep 1

# Discord
read -p "[*] Do you want to install Discord? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing Discord ..."
	sudo pacman -S discord --noconfirm && yay -S --noconfirm betterdiscord-installer
	echo "[*] Done."
else
	echo "[*] Discord installation skipped."
fi
sleep 1

# Apps for programming
read -p "[*] Do you want to install apps for programming? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    echo "[*] Installing apps for programming ..."
	yay -S --noconfirm visual-studio-code-bin intellij-idea-ultimate-edition webstorm neovim-nightly-bin
    echo "[*] Done."
else
    echo "[*] Apps for programming installation skipped."
fi
sleep 1

# Other apps
read -p "[*] Do you want to install other apps? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "[*] Installing other apps ..."
	sudo pacman -S vlc telegram-desktop --noconfirm && yay -S --noconfirm google-chrome
else
	echo "[*] Other apps installation skipped."
fi

# sudo pacman -S gnome-keyring libsecret libgnome-keyring seahorse xf86-input-libinput pacman-contrib wmctrl thefuck wget arandr gpick btop fontconfig ibus lsd jq github-cli polkit-gnome libwebp webp-pixbuf-loader physlock xss-lock betterlockscreen lightdm lightdm-webkit2-greeter && yay -S lightdm-webkit2-theme-glorious auto-cpufreq
