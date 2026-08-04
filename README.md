<h1>IT JUST MY SHELL SCRIPT FOR INSTALL ARCH LINUX</h1>

```zsh
sh -c "$(curl -sSL https://raw.githubusercontent.com/sownteedev/dotfiles/install/.archinstall)"
```

After the base and driver stages, install the shell in two explicit groups:

```zsh
~/Dotfiles/install/.installconfigtheme --shell-deps  # Required runtime
~/Dotfiles/install/.installconfigtheme --features    # Optional features
```

Use `INSTALLER_DRY_RUN=1` with either command to inspect package and `/usr`
actions without changing the machine. Both commands use `--needed`, so running
them again is safe.
