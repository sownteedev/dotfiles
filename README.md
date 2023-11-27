## Setup 🔧:

<details><summary>Package and Applications</summary><blockquote>

#### Apps

    sudo pacman -S dunst rofi alacritty && yay -S picom-ftlabs-git

#### Font

    yay -S ttf-font-awesome noto-fonts noto-fonts-cjk ttf-terminus-nerd ttf-inconsolata ttf-joypixels

#### Apps for Code

    yay -S visual-studio-code-bin intellij-idea-ultimate-edition webstorm neovim-nightly-bin

#### Other Apps

    sudo pacman -S discord betterdiscord-installer vlc telegram-desktop

    yay -S google-chrome spotify spicetify-cli spotifyd spotify-tui

#### Library Support

    sudo pacman -S nodejs npm yarn python python-pip clang jdk-openjdk rustup cargo

#### Network

    sudo pacman -S netctl networkmanager network-manager-applet ifplugd dhcpcd dialog wpa_supplicant wireless_tools

    sudo systemctl enable NetworkManager && sudo systemctl enable dhcpcd.service

#### Audio

    sudo pacman -S pavucontrol pipewire pipewire-alsa pipewire-audio pulseaudio pulseaudio-bluetooth playerctl pamixer mpd mpc ncmpcpp

    systemctl --user enable pipewire pipewire-pulse && systemctl --user start pipewire pipewire-pulse

    systemctl --user enable mpd.service && systemctl --user start mpd.service

#### Power

    sudo pacman -S acpi

#### Bluetooth

    sudo pacman -S bluez bluez-utils bluez-tools bluez-libs blueman

    sudo systemctl enable bluetooth.service && sudo systemctl start bluetooth.service

#### Brightness

    sudo pacman -S brightnessctl xorg-xbacklight

#### File Manager

    sudo pacman -S thunar tumbler nemo ranger ueberzug exa unzip unrar xdg-user-dirs && yay -S highlight

#### Monitor and Theme

    sudo pacman -S feh flameshot maim viewnior lxappearance neofetch && yay -S papirus-icon-theme imagemagick

#### Other

    sudo pacman -S gnome-keyring libsecret libgnome-keyring seahorse auto-cpufreq xf86-input-libinput pacman-contrib thefuck wget arandr gpick btop fontconfig ibus lsd jq github-cli polkit-gnome libwebp webp-pixbuf-loader physlock xss-lock betterlockscreen lightdm lightdm-webkit2-greeter && yay -S lightdm-webkit2-theme-glorious

</blockquote></details>

<details><summary>How to install Arch Linux</summary><blockquote>

### Make you have Internet

    iwctl

### Time sync and set keyboard

    loadkeys i386/qwerty/us.map.gz

    timedatectl set-ntp true

    timedatectl set-timezone Asia/Ho_Chi_Minh

### Reflector and Keyring

    pacman -Sy reflector archlinux-keyring

    reflector -c Vietnam -c Singapore -c Japan -c India -a 12 --sort rate --save /etc/pacman.d/mirrorlist

### Disk

    cfdisk /dev/sda

    mkswap /dev/sda6
    swapon /dev/sda6

    mkfs.ext4 /dev/sda5

    mount /dev/sda5 /mnt

    mkdir /mnt/efi
    mount /dev/sda1 /mnt/efi

### Install basic package

    pacstrap /mnt base base-devel linux linux-firmware linux-headers neovim

### Switch to /mnt

    genfstab -U /mnt >> /mnt/etc/fstab

    arch-chroot /mnt

### Set time and Languaue

    ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime

    hwclock --systohc

    nvim /etc/locale.gen

    Uncomment: en_US.UTF-8 UTF-8

    locale-gen

    echo LANG=en_US.UTF-8 > /etc/locale.conf

    export LANG=en_US.UTF-8

### Set hostname

    echo arch > /etc/hostname

    nvim /etc/hosts

    127.0.0.1[TAB]localhost
    ::1[TAB][TAB]localhost
    127.0.1.1[TAB]arch.localdomain[TAB]arch

### User add or password

    passwd

    useradd -m sowntee

    passwd sowntee

    usermod -aG wheel,audio,video,optical,storage,power sowntee

    EDITOR=nvim visudo

    Add: sowntee ALL=(ALL) ALL
    sowntee ALL=(ALL:ALL) NOPASSWD: /usr/bin/systemctl reboot, /usr/bin/systemctl poweroff
    Uncomment: %wheel ALL=(ALL) ALL

### Grub and OsProber

    sudo pacman -S grub os-prober efibootmgr ntfs-3g mtools dosfstools

    sudo nvim /etc/default/grub

    Uncomment: GRUB_DISABLE_OS_PROBER=false

    Try: sudo os-prober

    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB

    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck

    grub-mkconfig -o /boot/grub/grub.cfg

### Exit and Reboot

    exit

    reboot

</blockquote></details>
