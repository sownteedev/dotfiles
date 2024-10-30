if [ $(command -v exa) ]; then
    alias ll="exa --all --long --icons --group --git"
    alias ls="exa --icons"
fi

if [ $(command -v ripgrep) ]; then
    alias grep="ripgrep"
fi

usenvm() {
	sed -i 's/^# source \/usr\/share\/nvm\/init-nvm.sh/source \/usr\/share\/nvm\/init-nvm.sh/' ~/.config/zsh/.zshrc
	source ~/.config/zsh/.zshrc
    nvm use "$1"
	sed -i 's/^source \/usr\/share\/nvm\/init-nvm.sh/# source \/usr\/share\/nvm\/init-nvm.sh/' ~/.config/zsh/.zshrc
}

alias cls="clear"
alias nvide="neovide"

alias fzf="fzf --layout=reverse --prompt ' ' --pointer '=>' --preview='less {}' --bind shift-up:preview-page-up,shift-down:preview-page-down"

alias pacman="sudo pacman --noconfirm"
alias yay="yay --noconfirm"

alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias ......='cd ../../../../../'

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias dotpush='git add . && git commit -m ":>" && git push'
alias syncfont='sudo fc-cache -fv'

bindkey -s ^o "startx\n"
bindkey -s ^w "sudo mount -t ntfs-3g -o ro /dev/nvme0n1p2 $HOME/Windows\n"
bindkey '^e' "autosuggest-accept"

# vim:ft=zsh
