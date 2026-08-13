typeset -gr ZSH_CONFIG_DIR="${${(%):-%N}:A:h}"

for module in opts completion prompt alias plugins; do
    source "$ZSH_CONFIG_DIR/$module.zsh"
done
unset module

typeset -U path PATH
typeset -gx NPM_CONFIG_PREFIX="$HOME/.local"
typeset -gx PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
[[ -d "$PNPM_HOME/bin" ]] || command mkdir -p "$PNPM_HOME/bin"
path=(
    "$HOME/.local/bin"
    "$PNPM_HOME/bin"
    "$HOME/.local/share/nvim/mason/bin"
    $path
)

export EDITOR="nvim"
export VISUAL="$EDITOR"
