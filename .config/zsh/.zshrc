# source /usr/share/nvm/init-nvm.sh

typeset -gr ZSH_CONFIG_DIR="${${(%):-%N}:A:h}"

for module in opts completion prompt alias plugins; do
    source "$ZSH_CONFIG_DIR/$module.zsh"
done
unset module

typeset -U path PATH
path+=("$HOME/.local/bin" "$HOME/.local/share/nvim/mason/bin")

export EDITOR="nvim"
export VISUAL="$EDITOR"
