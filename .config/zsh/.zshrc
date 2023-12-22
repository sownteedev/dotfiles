[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

while read file
do 
  source "$HOME/.config/zsh/$file.zsh"
done <<-EOF
theme
alias
opts
plugs
prompt
EOF

for fun in ${(ok)functions[(I)[_][_][_][_][_]*]}; do 
  eval "alias ${${fun:5}//_/-}=\"${fun}\""
done

greet="xbl"
greet_path="$HOME/.bin/eyecandy/$greet"
[ -f "$greet_path" ] && eval "$greet_path" ||default_greeter
unset greet_path greet

# neofetch
$HOME/.local/bin/colorscript -r

export PATH=$PATH:~/.local/share/nvim/mason/bin

# Ibus
export GTK_IM_MODULE=ibus: warning
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx

export VISUAL=nvim;
export EDITOR=nvim;

# vim:ft=zsh:nowrap
