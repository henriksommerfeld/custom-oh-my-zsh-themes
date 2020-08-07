setopt prompt_subst
autoload -U colors && colors # Enable colors in prompt

# Echoes a username/host string when connected over SSH (empty otherwise)
ssh_info() {
  [[ "$SSH_CONNECTION" != '' ]] && echo '%(!.%{$fg[red]%}.%{$fg[yellow]%})%n%{$reset_color%}@%{$fg[green]%}%m%{$reset_color%}:' || echo ''
}

# Using https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/git.zsh
ZSH_THEME_GIT_PROMPT_PREFIX="\ue0a0 "
ZSH_THEME_GIT_PROMPT_SUFFIX=" "
ZSH_THEME_GIT_PROMPT_DIRTY=" 💩"      
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%} ✔️%{$reset_color%}"

ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_DETAILED=true
ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE="==="
ZSH_THEME_GIT_PROMPT_DIVERGED_REMOTE="<>"
ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE=" ⇡"
ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR="%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE=" ⇣"
ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR="%{$fg[cyan]%}"
ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_PREFIX="remote("
ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[red]%}●%{$reset_color%}"

local host='$(ssh_info)'
local current_dir='🥝 %{$terminfo[normal]$fg[magenta]%}%~ %{$reset_color%}'
local git_info='$(git_prompt_info) $(git_remote_status)'
local prompt='%(?.%{$fg[blue]%}.%{$fg[red]%})%(!.#.❯)%{$reset_color%} '

PROMPT="
${host}${current_dir} ${git_info}
${prompt}"