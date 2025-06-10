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

# preexec() {
#     local cmd="$1"
#     local dir="${PWD/#$HOME/~}"

#     if [[ ! "$cmd" =~ ^cd\ .* ]]; then
#        print -Pn "\e]0;$cmd  $dir\a"
#     fi
# }

# precmd() {
#     print -Pn "\e]0;${PWD/#$HOME/~}\a"
# }

export PATH=$PATH:~/.local/share/nvim/mason/bin
export VISUAL=nvim;
export EDITOR=nvim;
