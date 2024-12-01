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
autoload compinit
compinit

use romkatv/powerlevel10k 
use Aloxaf/fzf-tab
use zdharma-continuum/fast-syntax-highlighting
use zsh-users/zsh-autosuggestions
use hlissner/zsh-autopair
load zdharma-continuum/history-search-multi-word

unalias use snip ice load

# vim:ft=zsh
