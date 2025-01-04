usenvm() {
	sed -i 's/^# source \/usr\/share\/nvm\/init-nvm.sh/source \/usr\/share\/nvm\/init-nvm.sh/' ~/Dotfiles/dotf/.config/zsh/.zshrc
	source ~/.config/zsh/.zshrc
    nvm use "$1"
	sed -i 's/^source \/usr\/share\/nvm\/init-nvm.sh/# source \/usr\/share\/nvm\/init-nvm.sh/' ~/Dotfiles/dotf/.config/zsh/.zshrc
}

alias ll="exa --all --long --icons --group --git"
alias ls="exa --icons"

alias fzf="fzf --layout=reverse --prompt ' ' --pointer '=>' --preview='less {}' --bind shift-up:preview-page-up,shift-down:preview-page-down"

alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias ......='cd ../../../../../'

alias awesomewm="sed -i 's/dbus-run-session .*/dbus-run-session awesome/' ~/.xinitrc && startx"

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias dotpush='git add . && git commit -m ":>" && git push'
alias syncfont='sudo fc-cache -fv'

bindkey -s ^o "startx\n"
bindkey '^e' "autosuggest-accept"

# vim:ft=zsh
