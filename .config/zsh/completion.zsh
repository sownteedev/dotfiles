zmodload zsh/complist
autoload -Uz compinit

typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$ZSH_CACHE_DIR"

typeset -g ZSH_PLUGIN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
if [[ ! -d "$ZSH_PLUGIN_HOME/zsh-completions" ]]; then
    command mkdir -p "$ZSH_PLUGIN_HOME"
    print -P -- "%F{6}Installing Zsh plugin:%f zsh-completions"
    command git clone --quiet --depth=1 https://github.com/zsh-users/zsh-completions.git "$ZSH_PLUGIN_HOME/zsh-completions"
fi
fpath=("$ZSH_PLUGIN_HOME/zsh-completions/src" $fpath)

typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-${ZSH_VERSION}"
if [[ -s "$ZSH_COMPDUMP" && "$ZSH_COMPDUMP" -nt /usr/share/zsh/functions/Completion ]]; then
    compinit -C -d "$ZSH_COMPDUMP"
else
    compinit -d "$ZSH_COMPDUMP"
fi

zstyle ':completion:*' use-cache true
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/completion"
zstyle ':completion:*' menu no
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose true
zstyle ':completion:*' completer _extensions _complete _approximate
zstyle ':completion:*:descriptions' format '%F{8}── %d%f'\
zstyle ':completion:*:warnings' format '%F{1}no matches%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# fzf-tab appearance and previews.
zstyle ':fzf-tab:*' fzf-flags \
  --height=55% \
  --layout=reverse \
  --border=rounded \
  --info=inline-right \
  --scrollbar='│' \
  --prompt='   ' \
  --pointer=' ❯' \
  --marker=' ✓' \
  --color=fg:7,bg:-1,hl:4,fg+:15,bg+:0,hl+:12 \
  --color=info:8,prompt:4,pointer:5,marker:6,spinner:3,header:4
zstyle ':fzf-tab:*' switch-group ',' '.'
# Only show preview window for file-related commands, giving more space for others (like yay, git)
zstyle ':fzf-tab:complete:(cd|z|ls|ll|cat|bat|nvim|vi|vim|nano|rm|cp|mv):*' fzf-preview '~/.config/zsh/fzf-preview.sh $realpath'
