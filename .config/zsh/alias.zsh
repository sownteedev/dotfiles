if [ $(command -v exa) ]; then
    alias ll="exa --all --long --icons --group --git"
    alias ls="exa"
    alias la="exa --long --all --group"
fi

if [ $(command -v ripgrep) ]; then
    alias grep="ripgrep"
fi

eval "$(thefuck --alias)"

alias rec='ffmpeg -y -framerate 60 -f x11grab -i $DISPLAY -pix_fmt yuv420p $HOME/Videos/rec.mp4'
alias rec_audio='ffmpeg -y -framerate 60 -f x11grab -i $DISPLAY -f pulse -i alsa_output.pci-0000_00_1b.0.analog-stereo.monitor -pix_fmt yuv420p $HOME/Videos/rec.mp4'
alias rec_mic='ffmpeg -y -framerate 60 -f x11grab -i $DISPLAY -f pulse -i default -pix_fmt yuv420p $HOME/Videos/rec.mp4'

alias cls="clear"
alias nvide="neovide"

alias fzf="fzf --layout=reverse --prompt ' ' --pointer '=>' --preview='less {}' --bind shift-up:preview-page-up,shift-down:preview-page-down"

alias yts="ytfzf -t"
alias startx='startx -- -keeptty >~/.xorg.log 2>&1'

alias cd..='cd ../'
alias cd...='cd ../../'
alias cd....='cd ../../../'
alias cd.....='cd ../../../../'
alias cd......='cd ../../../../../'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias ......='cd ../../../../../'

alias t='tail -f'

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias -s pdf=zathura
alias -s ps=gv
alias -s dvi=xdvi
alias -s chm=xchm
alias -s djvu=djview

alias upgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias upfnt='sudo fc-cache -fv'

SILENT_JAVA_OPTIONS="$JDK_JAVA_OPTIONS"
alias java='java "$SILENT_JAVA_OPTIONS"'
alias nhist="dbus-monitor \"interface='org.freedesktop.Notifications'\" | grep --line-buffered \"member=Notify\|string\""
alias strel="xrdb -I$HOME/.config/Xresources $HOME/.config/Xresources/config.x && kill -USR1 $(pidof st)"

alias fet.sh="$HOME/.bin/eyecandy/fet.sh"
alias resrc="source $ZDOTDIR/.zshrc"

alias spotifyd="spotifyd --config-path '$HOME/.config/spotifyd/spotifyd.conf' --no-daemon"
alias wttr='curl wttr.in'
alias c='cd $(fd --type d . | fzf)'

bindkey -s ^n "nvims\n"

# vim:ft=zsh
