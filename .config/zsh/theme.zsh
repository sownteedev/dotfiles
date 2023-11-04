function default_greeter() {
  c1="\033[1;30m"
  c2="\033[1;31m"
  c3="\033[1;32m"
  c4="\033[1;33m"
  c5="\033[1;34m"
  c6="\033[1;35m"
  c7="\033[1;36m"
  c8="\033[1;37m"
  c9="\033[1;38m"
  c10="\033[1;39m"
  reset="\033[1;0m"
  printf "$c1▇▇ $c2▇▇ $c3▇▇ $c4▇▇ $c5▇▇ $c6▇▇ $c7▇▇ $c8▇▇ $c9▇▇ $c10▇▇ $reset\n"
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
# black
export foreground='#d4d4d5'
export background='#0E1115'

export base00='#171C21'
export base08='#949494'

# red
export base01='#f7467b'
export base09='#ff62a4'

# green
export base02='#1addb0'
export base10='#00ffb1'

# yellow
export base03='#ff8a30'
export base11='#FFC457'
 
# blue
export base04='#2798e4'
export base12='#53befc'

# magenta
export base05='#9554ff'
export base13='#B467F9'

# cyan
export base06='#2BCAFC'
export base14='#2bfcfc'

# white
export base07='#d4d4d5'
export base15='#ffffff'

if [ ! $(echo $MANPAGER | awk '{print $1}') = nvim ]; then
  export MANPAGER="less -s +M +Gg"
  export LESS="--RAW-CONTROL-CHARS"

  export LESS_TERMCAP_mb=$'\e[1;32m'
  export LESS_TERMCAP_md=$'\e[1;32m'
  export LESS_TERMCAP_me=$'\e[0m'
  export LESS_TERMCAP_se=$'\e[0m'
  export LESS_TERMCAP_so=$'\e[01;33m'
  export LESS_TERMCAP_ue=$'\e[0m'
  export LESS_TERMCAP_us=$'\e[1;4;31m'
fi

# FZF bases
export FZF_DEFAULT_OPTS="
  --color border:$base
  --color gutter:$base
  --prompt '  '
  --pointer ' '
  --border none
  --height 40"

# vim:filetype=zsh
