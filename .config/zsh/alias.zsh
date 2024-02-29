if [ $(command -v exa) ]; then
    alias ll="exa --all --long --icons --group --git"
    alias ls="exa"
    alias la="exa --long --all --group"
fi

if [ $(command -v ripgrep) ]; then
    alias grep="ripgrep"
fi

alias rec='ffmpeg -y -f x11grab -r 60 -i $DISPLAY -pix_fmt yuv420p -c:a aac -b:a 64k -b:v 500k -preset ultrafast -tune zerolatency -crf 28 ~/Videos/Recordings/$(date +%d-%m-%Y-%H:%M:%S).mp4'

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
alias startx='startx -- -keeptty >~/.xorg.log 2>&1'
alias fetch="$HOME/.local/bin/fetch"
alias spotifyd="spotifyd --config-path '$HOME/.config/spotifyd/spotifyd.conf' --no-daemon"

bindkey -s ^n "nvims\n"
bindkey -s ^o "startx\n"

# vim:ft=zsh
