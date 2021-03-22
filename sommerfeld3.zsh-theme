setopt prompt_subst
autoload -U colors && colors # Enable colors in prompt

# Echoes a username/host string when connected over SSH (empty otherwise)
ssh_info() {
  [[ "$SSH_CONNECTION" != '' ]] && echo '%(!.%{$fg[red]%}.%{$fg[yellow]%})%n%{$reset_color%}@%{$fg[green]%}%m%{$reset_color%}:' || echo ''
}

vpn_info() {
 local CONNECTED_VPN_NAME="$(scutil --nc list 2>&1 | grep "(Connected)" | cut -d'"' -f2)"
 local DISCONNECTED_VPN_NAME="$(scutil --nc list 2>&1 | grep "(Disconnected)" | cut -d'"' -f2)"

 if [ "$CONNECTED_VPN_NAME" ]; then
  print -P -- "%{$fg[green]%}🔒 %{$CONNECTED_VPN_NAME%}%{$reset_color%}"
 fi
}

wireguard_info() {
  local WG_NAME="$([ -d /var/run/wireguard ] && ls /var/run/wireguard | grep .name | cut -d'.' -f1 | cut -d'-' -f2)"

  if [ "$WG_NAME" ]; then
    print -P -- "%{$fg[green]%}🔒 %{$WG_NAME%}%{$reset_color%}"
  fi
}

# Echoes information about Git repository status when inside a Git repository
local AHEAD="%{$fg[red]%}NUM↑%{$reset_color%}"
local BEHIND="%{$fg[cyan]%}NUM↓%{$reset_color%}"
local MERGING="%{$fg[magenta]%}⚡︎%{$reset_color%}"
local UNTRACKED="%{$fg[red]%}NUM☀%{$reset_color%}"
local MODIFIED="%{$fg[yellow]%}NUM≠%{$reset_color%}"
local DELETED="%{$fg[yellow]%}NUM-%{$reset_color%}"
local STAGED_ADDED="%{$fg[green]%}NUM+%{$reset_color%}"
local STAGED_DELETED="%{$fg[green]%}NUM-%{$reset_color%}"
local STAGED_MODIFIED="%{$fg[green]%}NUM≠%{$reset_color%}"
local CLEAN="%{$fg[green]%}✔%{$reset_color%}"
local STASHES="%{$fg[cyan]%}NUM≡%{$reset_color%}"

git_info() {

  # Exit if not inside a Git repository
  ! git rev-parse --is-inside-work-tree > /dev/null 2>&1 && return

  # Git branch/tag, or name-rev if on detached head
  local GIT_LOCATION=${$(git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD)#(refs/heads/|tags/)}

  local HAS_UPSTREAM=false
  local UPSTREAM=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)
  if [[ -n "${UPSTREAM}" && "${UPSTREAM}" != "@{upstream}" ]]; then HAS_UPSTREAM=true; fi

  if [[ $HAS_UPSTREAM == false ]]; then
    GIT_LOCATION="$GIT_LOCATION (only local)"
  fi

  local -a DIVERGENCES
  local -a FLAGS

  local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_AHEAD" -gt 0 ]; then
    DIVERGENCES+=( "${AHEAD//NUM/$NUM_AHEAD} " )
  fi

  local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_BEHIND" -gt 0 ]; then
    DIVERGENCES+=( "${BEHIND//NUM/$NUM_BEHIND} " )
  fi

  local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
  if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
    FLAGS+=( "$MERGING " )
  fi

  local GIT_STAUS=$(git status --porcelain 2> /dev/null)

  # Staged

  local NUMBER_ADDED=$(\grep -c "^A" <<< "${GIT_STAUS}")
  local STAGED_NUMBER_DELETED=$(\grep -c "^D" <<< "${GIT_STAUS}")
  local STAGED_NUMBER_MODIFIED=$(\grep -c "^M" <<< "${GIT_STAUS}")

  if [[ $STAGED_NUMBER_MODIFIED -gt 0 ]]; then
    FLAGS+=( "${STAGED_MODIFIED//NUM/$STAGED_NUMBER_MODIFIED} " )
  fi

  if [[ $STAGED_NUMBER_DELETED -gt 0 ]]; then
    FLAGS+=( "${STAGED_DELETED//NUM/$STAGED_NUMBER_DELETED} " )
  fi

  if [[ $NUMBER_ADDED -gt 0 ]]; then
    FLAGS+=( "${STAGED_ADDED//NUM/$NUMBER_ADDED} " )
  fi

  # Not staged

  local NUMBER_DELETED=$(\grep -c "^.D" <<< "${GIT_STAUS}")
  local NUMBER_MODIFIED=$(\grep -c "^.M" <<< "${GIT_STAUS}")
  local NUMBER_UNTRACKED=$(\grep -c "^??" <<< "${GIT_STAUS}")

  if [[ $NUMBER_MODIFIED -gt 0 ]]; then
    FLAGS+=( "${MODIFIED//NUM/$NUMBER_MODIFIED} " )
  fi

  if [[ $NUMBER_DELETED -gt 0 ]]; then
    FLAGS+=( "${DELETED//NUM/$NUMBER_DELETED} " )
  fi

  if [[ $NUMBER_UNTRACKED -gt 0 ]]; then
    FLAGS+=( "${UNTRACKED//NUM/$NUMBER_UNTRACKED} " )
  fi

  local DIRTY=$(parse_git_dirty)
  if [[ -n $DIRTY ]]; then
  else
    FLAGS+=( "$CLEAN " )
  fi

  # Stashes
  local NUMBER_STASHES="$(git stash list 2> /dev/null | wc -l)"
  if [[ $NUMBER_STASHES -gt 0 ]]; then
    local TRIMMED_NUMBER="${NUMBER_STASHES##*(  )}"
    FLAGS+=( "${STASHES//NUM/$TRIMMED_NUMBER} " )
  fi

  local -a GIT_INFO
  GIT_INFO+=( "%{$fg[white]%}\ue0a0 $GIT_LOCATION" )
  [ -n "$GIT_STATUS" ] && GIT_INFO+=( "$GIT_STATUS" )
  [[ ${#DIVERGENCES[@]} -ne 0 ]] && GIT_INFO+=( "${(j::)DIVERGENCES}" )
  [[ ${#FLAGS[@]} -ne 0 ]] && GIT_INFO+=( "${(j::)FLAGS}" )
  echo "${(j: :)GIT_INFO}"
}

# Use ❯ as the non-root prompt character; # for root
# Change the prompt character color if the last command had a nonzero exit code
PS1='
$(ssh_info)%{$fg[magenta]%}%~%u $(git_info) $(wireguard_info) $(vpn_info)
%(?.%{$fg[blue]%}.%{$fg[red]%})%(!.#.❯)%{$reset_color%} '

help () {
  local gray=244
  print -P -- "GIT SYMBOLS IN THIS PROMPT EXPLAINED"
  echo
  print -P -- "\ue0a0 %F{$gray}\t# Start of Git prompt, followed by branch name%f"
  echo
  print -P -- "${AHEAD//NUM/1} %F{$gray}\t# 1 commit ahead%f"
  print -P -- "${BEHIND//NUM/1} %F{$gray}\t# 1 commit behind%f"
  echo
  print -P -- "${UNTRACKED//NUM/1} %F{$gray}\t# 1 untracked file%f"
  print -P -- "${MODIFIED//NUM/1} %F{$gray}\t# 1 modified file%f"
  print -P -- "${DELETED//NUM/1} %F{$gray}\t# 1 deleted file%f"
  echo
  print -P -- "${STAGED_ADDED//NUM/1} %F{$gray}\t# 1 added file (staged)%f"
  print -P -- "${STAGED_DELETED//NUM/1} %F{$gray}\t# 1 deleted file (staged)%f"
  print -P -- "${STAGED_MODIFIED//NUM/1} %F{$gray}\t# 1 modified file (staged)%f"
  echo
  print -P -- "${MERGING} %F{$gray}\t# merge conflict%f"
  print -P -- "${CLEAN} %F{$gray}\t# clean workspace%f"
  echo
  print -P -- "${STASHES//NUM/1} %F{$gray}\t# 1 stash%f"
  echo
  echo

  print -P -- "PROMPT"
  echo
  print -P -- "$fg[blue]❯ %F{$gray}\t# Previous command successful exit code %f"
  print -P -- "$fg[red]❯ %F{$gray}\t# Previous command bad exit code %f"
  print -P -- "$fg[red]# %F{$gray}\t# Running as root %f"
}
