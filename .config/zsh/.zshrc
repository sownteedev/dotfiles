# source /usr/share/nvm/init-nvm.sh

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

[ -f "$greet_path" ] && eval "$greet_path" || default_greeter

export PATH=$PATH:~/.local/share/nvim/mason/bin

export VISUAL=nvim;
export EDITOR=nvim;
