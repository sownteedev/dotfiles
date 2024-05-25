if [ $(command -v exa) ]; then
    alias ll="exa --all --long --icons --group --git"
    alias ls="exa"
    alias la="exa --long --all --group"
fi

if [ $(command -v ripgrep) ]; then
    alias grep="ripgrep"
fi

alias rel="xrdb merge ~/.Xresources && kill -USR1 $(pidof st)"
alias cls="clear"
alias nvide="neovide"

alias fzf="fzf --layout=reverse --prompt ' ' --pointer '=>' --preview='less {}' --bind shift-up:preview-page-up,shift-down:preview-page-down"

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
alias windows='sudo mount -t ntfs-3g -o ro /dev/nvme0n1p2 $HOME/Windows'
alias startx='startx -- -keeptty >~/.xorg.log 2>&1'
alias fetch="$HOME/.local/bin/fetch"
alias trans="$HOME/.local/bin/trans"
alias wal="$HOME/.local/bin/wal"

bindkey -s ^n "nvims\n"
bindkey -s ^o "startx\n"
bindkey -s ^w "sudo mount -t ntfs-3g -o ro /dev/nvme0n1p3 $HOME/Windows\n"
bindkey '^e' "autosuggest-accept"

# vim:ft=zsh
