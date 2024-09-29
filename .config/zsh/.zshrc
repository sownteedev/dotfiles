[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

while read file
do 
  source "$HOME/.config/zsh/$file.zsh"
done <<-EOF
plugs
theme
alias
opts
prompt
EOF

for fun in ${(ok)functions[(I)[_][_][_][_][_]*]}; do 
  eval "alias ${${fun:5}//_/-}=\"${fun}\""
done

[ -f "$greet_path" ] && eval "$greet_path" || default_greeter

export PATH=$PATH:~/.local/share/nvim/mason/bin

export VISUAL=nvim;
export EDITOR=nvim;

# vim:ft=zsh:nowrap
