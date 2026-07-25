# Plugins live outside the dotfiles repository. Missing plugins are installed
# once, then sourced directly on every subsequent shell startup.
typeset -g ZSH_PLUGIN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
typeset -ga ZSH_PLUGIN_NAMES=(
    fzf-tab
    autopair
    zsh-autosuggestions
    zsh-syntax-highlighting
)
typeset -gA ZSH_PLUGIN_REPOSITORIES=(
    fzf-tab                https://github.com/Aloxaf/fzf-tab.git
    autopair               https://github.com/hlissner/zsh-autopair.git
    zsh-autosuggestions    https://github.com/zsh-users/zsh-autosuggestions.git
    zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
)

_zsh_load_plugin() {
    emulate -L zsh

    local name="$1"
    local entrypoint="$2"
    local target="$ZSH_PLUGIN_HOME/$name"
    local source_file="$target/$entrypoint"
    local temporary="${target}.tmp.$$"

    if [[ ! -r "$source_file" ]]; then
        if (( ! $+commands[git] )); then
            print -u2 -- "zsh: cannot install $name because git is unavailable"
            return 1
        fi

        command mkdir -p -- "$ZSH_PLUGIN_HOME"
        command rm -rf -- "$temporary"
        print -P -- "%F{6}Installing Zsh plugin:%f $name"

        if ! command git clone --quiet --depth=1 --single-branch \
            "$ZSH_PLUGIN_REPOSITORIES[$name]" "$temporary"; then
            command rm -rf -- "$temporary"
            print -u2 -- "zsh: failed to install plugin $name"
            return 1
        fi

        command rm -rf -- "$target"
        command mv -- "$temporary" "$target"
    fi

    source "$source_file"
}

zsh-plugins-update() {
    emulate -L zsh

    local name
    local target
    local status=0

    for name in "${ZSH_PLUGIN_NAMES[@]}"; do
        target="$ZSH_PLUGIN_HOME/$name"
        if [[ -d "$target/.git" ]]; then
            print -P -- "%F{6}Updating Zsh plugin:%f $name"
            command git -C "$target" pull --ff-only || status=1
        else
            print -u2 -- "zsh: plugin is not installed: $name"
            status=1
        fi
    done

    return "$status"
}

_zsh_load_plugin fzf-tab fzf-tab.plugin.zsh
_zsh_load_plugin autopair autopair.zsh

export FZF_DEFAULT_OPTS="
  --height=55%
  --layout=reverse
  --border=rounded
  --info=inline-right
  --scrollbar='│'
  --prompt='   '
  --pointer=' ❯'
  --marker=' ✓'
  --color=fg:7,bg:-1,hl:4,fg+:15,bg+:0,hl+:12
  --color=info:8,prompt:4,pointer:5,marker:6,spinner:3,header:4
"

typeset -gx FZF_CTRL_R_OPTS="--preview-window=hidden"
if [[ -r /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh
fi

typeset -g ZSH_AUTOSUGGEST_USE_ASYNC=true
typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
_zsh_load_plugin zsh-autosuggestions zsh-autosuggestions.zsh

# Syntax highlighting must be sourced after every widget and key binding.
typeset -ga ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
_zsh_load_plugin zsh-syntax-highlighting zsh-syntax-highlighting.zsh

unfunction _zsh_load_plugin
