# source /usr/share/nvm/init-nvm.sh

while read file
do 
  source "$HOME/.config/zsh/$file.zsh"
done <<-EOF
plugs
alias
opts
prompt
EOF

export PATH=$PATH:~/.local/share/nvim/mason/bin
export VISUAL=nvim;
export EDITOR=nvim;
