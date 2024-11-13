<h1 align="center">m<span style="color:#59929d;">AWM</span>cos</h1>

<div align="center">

<img src="https://github.com/user-attachments/assets/c897d7d5-ecae-44ca-a0da-14d6ec2b6186">

</div>

<br>

<br>

<div align="center">

![GitHub top language](https://img.shields.io/github/languages/top/sownteedev/dotfiles?color=6d92bf&style=for-the-badge&labelColor=111418)
![Last Commit](https://img.shields.io/github/last-commit/sownteedev/dotfiles?&style=for-the-badge&color=da696f&logoColor=D9E0EE&labelColor=111418)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/sownteedev/dotfiles?color=e1b56a&style=for-the-badge&labelColor=111418)
![GitHub Repo stars](https://img.shields.io/github/stars/sownteedev/dotfiles?color=74be88&style=for-the-badge&labelColor=111418)

</div>

## Introduction

Welcome to a unique window management experience that combines the power of AwesomeWM with the elegance of MacOS! This custom setup transforms AwesomeWM into a sleek, MacOS-inspired desktop environment while preserving the extensive customization and efficiency that AwesomeWM users know and love. By blending familiar MacOS elements—such as a dock, top bar, and smooth animations—with the flexibility of a tiling window manager, this configuration delivers a refined yet powerful user experience.

The desktop setup includes a variety of widgets designed to resemble MacOS features, such as a control center for quick access to system controls, a notifications area, and interactive app icons. The dock behaves intuitively, offering smooth animations and shortcuts to your favorite applications, while the top bar displays useful information in a clean, polished layout. This MacOS-style interface allows you to enjoy the aesthetic appeal of Apple’s design while retaining AwesomeWM’s lightweight and customizable core.

Whether you are a fan of MacOS aesthetics or simply looking for a fresh take on your Linux desktop, this AwesomeWM configuration provides a stylish, responsive, and efficient environment that is as functional as it is beautiful.

## Features

- **MacOS-style Dock**: A customizable dock with smooth animations for quick app launching.

- **Top Bar**: A clean, informative top bar displaying system status and quick access to controls.

- **Interactive Widgets**: The popup widgets are really cool, they automatically dim when an application is open

- **Control center**: A MacOS-inspired control center providing quick access to essential system controls like brightness, volume, and Wi-Fi. Designed to open with a smooth animation, it enables you to make adjustments seamlessly without leaving your workspace.

- **Notificenter**: A dedicated area for managing notifications, styled to resemble the MacOS notification center. It allows you to view recent notifications in an organized manner, keeping you informed without distraction.

- **Animations**: Subtle animations to enhance the visual appeal and responsiveness.

## Requirements

- **AwesomeWM** (version 4.3 or higher)

- **LuaJIT** for better performance

- **LuaPAM** for keylock

- **Picom** for animations and transparency effects

- **Other Dependencies**:
  - `playerctl` `pamixer`

  - `inotify-tools`

  - `redshift` `brightnessctl`

  - `acpi` `acpid` `upower` `power-profiles-daemon`

  - `networkmanager` `bluetoothctl`

## Usage 

- Backup your config
  ```zsh
  mv ~/.config/awesome ~/.config/awesome.bak
  ```
- Install MAWMCOS
  ```zsh
  git clone https://github.com/sownteedev/dotfiles ~/.config/awesome --branch=mAWMcos --depth=1
  ```
- All global variables will be used in `user.lua`, let's edit this.

- There will be things of mine that will not be necessary for you, please read and maybe delete them.


### Screenshots

| <b>Desktop and Widgets</b>                                                                                               |
| ------------------------------------------------------------------------------------------------------------------ |
| <a href="#--------"><img src="https://github.com/user-attachments/assets/5377de5d-266a-4024-80f8-2a28a9dc867c" alt="bottom panel preview"></a>|

| <b>Control Center</b>                                                                              |
| ------------------------------------------------------------------------------------------------------------------ |
| <a href="#--------"><img src="https://github.com/user-attachments/assets/cd47563a-d484-4553-9020-a560244e7385" alt="bottom panel preview"></a>|

| <b>Notification Center</b>                                                                                   |
| ------------------------------------------------------------------------------------------------------------------ |
| <a href="#--------"><img src="https://github.com/user-attachments/assets/59c087db-f839-4e06-a8e8-cb445e890bcd" alt="bottom panel preview"></a>|

| <b>Lock Screen</b>                                                                            |
| ------------------------------------------------------------------------------------------------------------------ |
| <a href="#--------"><img src="https://github.com/user-attachments/assets/4f151ed5-dea0-47f5-bf0b-8786c36d6414" alt="bottom panel preview"></a>|

| <b>Preview Workspace</b>                                                                            |
| ------------------------------------------------------------------------------------------------------------------ |
| <a href="#--------"><img src="https://github.com/user-attachments/assets/586ab6ce-a229-4264-9362-8bb97887ac56" alt="bottom panel preview"></a>|

| <b>Titlebar and Widget flexibility</b>                                                                            |
| ------------------------------------------------------------------------------------------------------------------ |
| <a href="#--------"><img src="https://github.com/user-attachments/assets/874c1211-48e6-4473-a593-0a8f7497a325" alt="bottom panel preview"></a>|
