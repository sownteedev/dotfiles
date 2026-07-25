usenvm() {
	sed -i 's/^# source \/usr\/share\/nvm\/init-nvm.sh/source \/usr\/share\/nvm\/init-nvm.sh/' ~/Dotfiles/dotf/.config/zsh/.zshrc
	source ~/.config/zsh/.zshrc
    nvm use "$1"
	sed -i 's/^source \/usr\/share\/nvm\/init-nvm.sh/# source \/usr\/share\/nvm\/init-nvm.sh/' ~/Dotfiles/dotf/.config/zsh/.zshrc
}

# claude_execute: Generate exact shell command from natural language; reasoning off; auto-executes; globbing disabled
claude_execute() {
	emulate -L zsh
	setopt NO_GLOB
	local query="$*"
	local prompt="You are a command line expert. The user wants to run a command but they don't know how. Here is what they asked: ${query}. Return ONLY the exact shell command needed. Do not prepend with an explanation, no markdown, no code blocks - just return the raw command you think will solve their query."
	local cmd
	# use Claude Code
	cmd=$(claude --dangerously-skip-permissions --disallowedTools "Bash(*)" --model default -p "$prompt" --output-format text | tr -d '\000-\037' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	# use Gemini CLI
	if [[ -z "$cmd" ]]; then
		echo "claude_execute: No command found"
		return 1
	fi
	echo -e "$ \033[0;36m$cmd\033[0m"
	eval "$cmd"
}
alias ce="noglob claude_execute"

alias ll="eza --all --long --icons=auto --group --git"
alias ls="eza --icons=auto"

alias fzf="fzf --layout=reverse --prompt ' ' --pointer '=>' --preview='less {}' --bind shift-up:preview-page-up,shift-down:preview-page-down"

alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias ......='cd ../../../../../'

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias dotpush='git add . && git commit -m ":>" && git push'
alias syncfont='sudo fc-cache -fv'
alias cleanarch='sudo paccache -ruk0 && yay -Sc --noconfirm && sudo pacman -Scc --noconfirm && sudo pacman -Rns $(pacman -Qtdq) --noconfirm'

bindkey '^e' "autosuggest-accept"

if command -v thefuck >/dev/null 2>&1; then
    eval $(thefuck --alias)
fi

# vim:ft=zsh
