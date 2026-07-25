autoload -Uz add-zsh-hook vcs_info
zmodload zsh/datetime
zmodload zsh/parameter

# Git information.
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr ' %F{10}+%f'
zstyle ':vcs_info:git:*' unstagedstr ' %F{9}!%f'
zstyle ':vcs_info:git:*' formats '%F{10} %b%f%u%c'
zstyle ':vcs_info:git:*' actionformats '%F{10} %b%f %F{11}(%a)%f%u%c'

typeset -g _prompt_command_started=0
typeset -g _prompt_directory=''
typeset -g _prompt_duration=''
typeset -g _prompt_environment=''
typeset -g _prompt_last_project_dir=''
typeset -g _prompt_right=''
typeset -g _prompt_symbol_color='10'

_prompt_project_environment() {
    [[ "$PWD" == "$_prompt_last_project_dir" ]] && return
    _prompt_last_project_dir="$PWD"

    local -a environments
    local version

    if [[ -n "$VIRTUAL_ENV" ]]; then
        environments+=("%F{4} ${VIRTUAL_ENV:t}%f")
    elif [[ -n "$PYENV_VERSION" ]]; then
        environments+=("%F{4} ${PYENV_VERSION}%f")
    elif [[ -f .python-version ]]; then
        version="$(<.python-version)"
        version="${version%%$'\n'*}"
        version="${version//[[:space:]]/}"
        [[ -n "$version" ]] && environments+=("%F{4} ${version}%f")
    fi

    if [[ -n "$NVM_BIN" ]]; then
        environments+=("%F{2} ${NVM_BIN:h:t}%f")
    elif [[ -f .nvmrc ]]; then
        version="$(<.nvmrc)"
        version="${version%%$'\n'*}"
        version="${version//[[:space:]]/}"
        [[ -n "$version" ]] && environments+=("%F{2} ${version}%f")
    elif [[ -f package.json && -n "${commands[node]-}" ]]; then
        version="$("${commands[node]}" --version 2>/dev/null)"
        [[ -n "$version" ]] && environments+=("%F{2} ${version}%f")
    fi

    if [[ -f go.mod && -n "${commands[go]-}" ]]; then
        version="$("${commands[go]}" version 2>/dev/null)"
        version="${version#go version }"
        version="${version%% *}"
        [[ -n "$version" ]] && environments+=("%F{6} ${version}%f")
    fi

    if [[ -n "$RUSTUP_TOOLCHAIN" ]]; then
        environments+=("%F{3} ${RUSTUP_TOOLCHAIN%%-*}%f")
    elif [[ -f Cargo.toml && -n "${commands[rustc]-}" ]]; then
        version="$("${commands[rustc]}" --version 2>/dev/null)"
        version="${version#rustc }"
        version="${version%% *}"
        [[ -n "$version" ]] && environments+=("%F{3} ${version}%f")
    fi

    if [[ -n "$JAVA_HOME" ]]; then
        version="${JAVA_HOME:t}"
        environments+=("%F{1} ${version}%f")
    elif [[ -f pom.xml || -f build.gradle || -f build.gradle.kts ]] && [[ -n "${commands[java]-}" ]]; then
        version="$("${commands[java]}" -version 2>&1)"
        if [[ "$version" =~ '"([^"]+)"' ]]; then
            version="${match[1]}"
        else
            version=''
        fi
        [[ -n "$version" ]] && environments+=("%F{1} ${version}%f")
    fi

    _prompt_environment="${(j: :)environments}"
}

_prompt_preexec() {
    _prompt_command_started="$EPOCHREALTIME"
}

_prompt_precmd() {
    local last_status=$?
    local -a right_segments
    local elapsed
    local segment

    vcs_info
    _prompt_project_environment
    _prompt_directory="${(%):-%2~}"
    _prompt_directory="${_prompt_directory/#\~/ }"

    if (( last_status == 0 )); then
        _prompt_symbol_color='10'
    else
        _prompt_symbol_color='9'
        right_segments+=("%F{9}✘ ${last_status}%f")
    fi

    _prompt_duration=''
    if (( _prompt_command_started > 0 )); then
        elapsed=$(( EPOCHREALTIME - _prompt_command_started ))
        if (( elapsed >= 1.0 )); then
            if (( elapsed >= 60.0 )); then
                _prompt_duration="$(( int(elapsed / 60) ))m $(( int(elapsed) % 60 ))s"
            else
                printf -v _prompt_duration '%.1fs' "$elapsed"
            fi
            right_segments+=("%F{11}󱎫 ${_prompt_duration}%f")
        fi
    fi
    _prompt_command_started=0

    (( ${#jobstates} > 0 )) && right_segments+=("%F{11}󰜎 ${#jobstates}%f")
    
    [[ -n "$_prompt_environment" ]] && right_segments+=("%F{4}${_prompt_environment}%f")
    
    [[ -n "$vcs_info_msg_0_" ]] && right_segments+=("%F{12}${vcs_info_msg_0_}%f")

    _prompt_right="${(j: :)right_segments}"
}

add-zsh-hook preexec _prompt_preexec
add-zsh-hook precmd _prompt_precmd

PROMPT=$'\n''%F{4} %f %F{8}❯%f %F{15}${_prompt_directory}%f %F{${_prompt_symbol_color}}❯%f '
RPROMPT='${_prompt_right}'
