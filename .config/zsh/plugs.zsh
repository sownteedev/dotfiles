ZINIT_HOME="$HOME/.local/share/zsh/zinit"
if [ ! -d "$ZINIT_HOME" ]; then
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "$ZINIT_HOME/zinit.zsh"
alias use='zinit light'
alias snip='zinit snippet'
alias ice='zinit ice'
alias load='zinit load'

ice depth"1"
use zsh-users/zsh-completions

autoload compinit
compinit

use romkatv/powerlevel10k 
use Aloxaf/fzf-tab
use zdharma-continuum/fast-syntax-highlighting
use zsh-users/zsh-autosuggestions
use hlissner/zsh-autopair 
use MichaelAquilina/zsh-you-should-use 

# FZF tab is better. Fight me.
# use marlonrichert/zsh-autocomplete 

# ice wait'3' lucid
load zsh-users/zsh-history-substring-search 

# ice wait'2' lucid
load zdharma-continuum/history-search-multi-word

# ice wait'5' lucid
unalias use snip ice load

# vim:ft=zsh
