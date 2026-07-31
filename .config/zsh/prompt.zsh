autoload -Uz add-zsh-hook vcs_info
zmodload zsh/datetime
zmodload zsh/parameter

# Git information.
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr ' +'
zstyle ':vcs_info:git:*' unstagedstr ' !'
zstyle ':vcs_info:git:*' formats '%b%u%c'
zstyle ':vcs_info:git:*' actionformats '%b (%a)%u%c'

typeset -g _prompt_command_started=0
typeset -g _prompt_directory=''
typeset -g _prompt_duration=''
typeset -g _prompt_environment=''
typeset -g _prompt_last_project_dir=''
typeset -g _prompt_right=''
typeset -g _prompt_symbol_color='10'

# Build the paired icon/value blocks used by the right prompt. Indexed terminal
# colors keep the prompt in sync with the palette generated for Blackbox.
_prompt_segment() {
    local icon="$1"
    local value="$2"
    local accent="${3:-4}"

    REPLY="%K{${accent}}%F{232} ${icon} %k%K{237}%F{15} ${value} %k"
}

_prompt_project_environment() {
    [[ "$PWD" == "$_prompt_last_project_dir" ]] && return
    _prompt_last_project_dir="$PWD"

    local -a environments
    local version

    if [[ -n "$VIRTUAL_ENV" ]]; then
        _prompt_segment '' "${VIRTUAL_ENV:t}"
        environments+=("$REPLY")
    elif [[ -n "$PYENV_VERSION" ]]; then
        _prompt_segment '' "$PYENV_VERSION"
        environments+=("$REPLY")
    elif [[ -f .python-version ]]; then
        version="$(<.python-version)"
        version="${version%%$'\n'*}"
        version="${version//[[:space:]]/}"
        if [[ -n "$version" ]]; then
            _prompt_segment '' "$version"
            environments+=("$REPLY")
        fi
    fi

    if [[ -n "$NVM_BIN" ]]; then
        _prompt_segment '' "${NVM_BIN:h:t}"
        environments+=("$REPLY")
    elif [[ -f .nvmrc ]]; then
        version="$(<.nvmrc)"
        version="${version%%$'\n'*}"
        version="${version//[[:space:]]/}"
        if [[ -n "$version" ]]; then
            _prompt_segment '' "$version"
            environments+=("$REPLY")
        fi
    elif [[ -f package.json && -n "${commands[node]-}" ]]; then
        version="$("${commands[node]}" --version 2>/dev/null)"
        if [[ -n "$version" ]]; then
            _prompt_segment '' "$version"
            environments+=("$REPLY")
        fi
    fi

    if [[ -f go.mod && -n "${commands[go]-}" ]]; then
        version="$("${commands[go]}" version 2>/dev/null)"
        version="${version#go version }"
        version="${version%% *}"
        if [[ -n "$version" ]]; then
            _prompt_segment '' "$version"
            environments+=("$REPLY")
        fi
    fi

    if [[ -n "$RUSTUP_TOOLCHAIN" ]]; then
        _prompt_segment '' "${RUSTUP_TOOLCHAIN%%-*}"
        environments+=("$REPLY")
    elif [[ -f Cargo.toml && -n "${commands[rustc]-}" ]]; then
        version="$("${commands[rustc]}" --version 2>/dev/null)"
        version="${version#rustc }"
        version="${version%% *}"
        if [[ -n "$version" ]]; then
            _prompt_segment '' "$version"
            environments+=("$REPLY")
        fi
    fi

    if [[ -n "$JAVA_HOME" ]]; then
        version="${JAVA_HOME:t}"
        _prompt_segment '' "$version"
        environments+=("$REPLY")
    elif [[ -f pom.xml || -f build.gradle || -f build.gradle.kts ]] && [[ -n "${commands[java]-}" ]]; then
        version="$("${commands[java]}" -version 2>&1)"
        if [[ "$version" =~ '"([^"]+)"' ]]; then
            version="${match[1]}"
        else
            version=''
        fi
        if [[ -n "$version" ]]; then
            _prompt_segment '' "$version"
            environments+=("$REPLY")
        fi
    fi

    _prompt_environment="${(j: :)environments}"
}

_prompt_preexec() {
    _prompt_command_started="$EPOCHREALTIME"
}

_prompt_precmd() {
    local last_status=$?
    local -a right_segments
    local -a job_commands
    local elapsed
    local elapsed_seconds
    local job_label

    vcs_info
    _prompt_project_environment
    _prompt_directory="${(%):-%2~}"
    _prompt_directory="${_prompt_directory/#\~/ }"

    if (( last_status == 0 )); then
        _prompt_symbol_color='10'
    else
        _prompt_symbol_color='9'
        _prompt_segment '' "$last_status" 1
        right_segments+=("$REPLY")
    fi

    _prompt_duration=''
    if (( _prompt_command_started > 0 )); then
        elapsed=$(( EPOCHREALTIME - _prompt_command_started ))
        if (( elapsed >= 1.0 )); then
            if (( elapsed >= 60.0 )); then
                elapsed_seconds="${elapsed%.*}"
                _prompt_duration="$(( elapsed_seconds / 60 ))m $(( elapsed_seconds % 60 ))s"
            else
                printf -v _prompt_duration '%.1fs' "$elapsed"
            fi
            _prompt_segment '󱎫' "$_prompt_duration"
            right_segments+=("$REPLY")
        fi
    fi
    _prompt_command_started=0

    if (( ${#jobstates} > 0 )); then
        job_commands=("${(v)jobtexts[@]}")
        job_label="${job_commands[1]%% *}"
        job_label="${job_label:t}"
        [[ -z "$job_label" ]] && job_label="${#jobstates} running"
        (( ${#jobstates} > 1 )) && job_label+=" +$(( ${#jobstates} - 1 ))"
        _prompt_segment '󰜎' "$job_label"
        right_segments+=("$REPLY")
    fi

    [[ -n "$_prompt_environment" ]] && right_segments+=("${_prompt_environment}")

    if [[ -n "$vcs_info_msg_0_" ]]; then
        _prompt_segment '' "$vcs_info_msg_0_"
        right_segments+=("$REPLY")
    fi

    _prompt_segment '󰒋' '%m'
    right_segments+=("$REPLY")

    _prompt_right="${(j: :)right_segments}"
}

add-zsh-hook preexec _prompt_preexec
add-zsh-hook precmd _prompt_precmd

PROMPT=$'\n''%K{4}%F{232}   %k%K{237}%F{15} ${_prompt_directory} %k %F{${_prompt_symbol_color}}❯%f '
RPROMPT='${_prompt_right}'
