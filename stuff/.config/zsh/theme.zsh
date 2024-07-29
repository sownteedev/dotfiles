function default_greeter() {
  c1="\033[1;30m"
  c2="\033[1;31m"
  c3="\033[1;32m"
  c4="\033[1;33m"
  c5="\033[1;34m"
  c6="\033[1;35m"
  c7="\033[1;36m"
  c8="\033[1;37m"
  printf "$c1▇▇ $c2▇▇ $c3▇▇ $c4▇▇ $c5▇▇ $c6▇▇ $c7▇▇ $c8▇▇ $reset\n\n"
}

function toggle_prompt() {
  case "$1" in
    right) p10k display '*/right'=hide,show ;;
    left) p10k display '*/left'=hide,show ;;
  esac
}

function toggle_right_prompt() {
  toggle_prompt right
}

function toggle_left_prompt() {
  toggle_prompt left
}

# Colors
export bgl=#161819

# FZF bases
export FZF_DEFAULT_OPTS="
  --color border:$bgl
  --color gutter:$bgl
  --color bg+:$bgl
  --prompt '  '
  --pointer ' '
  --border none
  --height 40"

# vim:filetype=zsh
