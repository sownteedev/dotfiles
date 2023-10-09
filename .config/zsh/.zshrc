[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

while read file
do 
  source "$HOME/.config/zsh/$file.zsh"
done <<-EOF
theme
alias
opts
plugs
prompt
EOF

for fun in ${(ok)functions[(I)[_][_][_][_][_]*]}; do 
  eval "alias ${${fun:5}//_/-}=\"${fun}\""
done

greet="xbl"
greet_path="$HOME/.bin/eyecandy/$greet"
[ -f "$greet_path" ] && eval "$greet_path" ||default_greeter
unset greet_path greet

# neofetch
$HOME/.local/bin/colorscript -r

# Switch Neovim config ^^
alias nvim-sowntee="NVIM_APPNAME=SownteeNvim nvim"
alias nvim-nvchad="NVIM_APPNAME=NvChad nvim"
alias nvim-lazy="NVIM_APPNAME=Lazy nvim"
alias nvim-astro="NVIM_APPNAME=Astro nvim"
alias nvim-tamton="NVIM_APPNAME=Tamton nvim"
alias nvim-kodo="NVIM_APPNAME=Kodo nvim"
alias nvim-mono="NVIM_APPNAME=Mono nvim"

function nvims() {
  items=("SownteeNvim" "NvChad" "Kodo" "Mono" "Lazy" "Astro" "Tamton")
  config=$(printf "%s\n" "${items[@]}" | fzf --prompt="  Neovim Config  " --height=~50% --layout=reverse --border --exit-0)
  if [[ -z $config ]]; then
    echo "Nothing selected"
    return 0
  elif [[ $config == "default" ]]; then
    config=""
  fi
  NVIM_APPNAME=$config nvim $@
}

export PATH=$PATH:~/.local/share/nvim/mason/bin

# Ibus
export GTK_IM_MODULE=ibus: warning
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx

# vim:ft=zsh:nowrap
