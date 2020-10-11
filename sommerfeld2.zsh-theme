# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

# Get colors: spectrum_ls

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

# Characters
SEGMENT_SEPARATOR="\ue0b0"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u2699"

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    print -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ $(id -u) -ne 0 ]]; then
    prompt_segment 255 232 "$USER@%m% "
  else
    prompt_segment 124 231 "$USER@%m% "
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  #«»±˖˗‑‐‒ ━ ✚‐↔←↑↓→↭⇎⇔⋆━◂▸◄►◆☀★☗☊✔✖❮❯⚑⚙
  PL_BRANCH_CHAR() {
    local LC_ALL=""
    local LC_CTYPE="en_US.UTF-8"
    local PL_BRANCH_CHAR="$BRANCH"
  }
  local ref dirty mode repo_path clean has_upstream
  local modified untracked added deleted tagged stashed
  local ready_commit git_status bgclr fgclr
  local commits_diff commits_ahead commits_behind has_diverged to_push to_pull

  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    git_status=$(git status --porcelain 2>/dev/null)
    ref=$(git symbolic-ref HEAD 2>/dev/null) || ref="➦ $(git rev-parse --short HEAD 2>/dev/null)"
    if [[ -n $dirty ]]; then
      clean=''
      bgclr='226'
      fgclr='232'
    else
      clean=' ✔️'
      bgclr='082'
      fgclr='232'
    fi

    local upstream=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2>/dev/null)
    if [[ -n "${upstream}" && "${upstream}" != "@{upstream}" ]]; then has_upstream=true; fi

    local current_commit_hash=$(git rev-parse HEAD 2>/dev/null)

    local number_of_untracked_files=$(\grep -c "^??" <<<"${git_status}")
    if [[ $number_of_untracked_files -gt 0 ]]; then untracked=" $number_of_untracked_files☀"; fi

    local number_added=$(\grep -c "^A" <<<"${git_status}")
    if [[ $number_added -gt 0 ]]; then added=" $number_added✚"; fi

    local number_modified=$(\grep -c "^.M" <<<"${git_status}")
    if [[ $number_modified -gt 0 ]]; then
      modified=" $number_modified≠"
      bgclr='197'
      fgclr='232'
    fi

    local number_added_modified=$(\grep -c "^M" <<<"${git_status}")
    local number_added_renamed=$(\grep -c "^R" <<<"${git_status}")
    if [[ $number_modified -gt 0 && $number_added_modified -gt 0 ]]; then
      modified="$modified$((number_added_modified + number_added_renamed))±"
    elif [[ $number_added_modified -gt 0 ]]; then
      modified=" ≠$((number_added_modified + number_added_renamed))±"
    fi

    local number_deleted=$(\grep -c "^.D" <<<"${git_status}")
    if [[ $number_deleted -gt 0 ]]; then
      deleted=" $number_deleted‒"
      bgclr='197'
      fgclr='232'
    fi

    local number_added_deleted=$(\grep -c "^D" <<<"${git_status}")
    if [[ $number_deleted -gt 0 && $number_added_deleted -gt 0 ]]; then
      deleted="$deleted$number_added_deleted±"
    elif [[ $number_added_deleted -gt 0 ]]; then
      deleted=" ‒$number_added_deleted±"
    fi

    local tag_at_current_commit=$(git describe --exact-match --tags $current_commit_hash 2>/dev/null)
    if [[ -n $tag_at_current_commit ]]; then tagged=" 🏷$tag_at_current_commit "; fi

    local number_of_stashes="$(git stash list -n1 2>/dev/null | wc -l)"
    if [[ $number_of_stashes -gt 0 ]]; then
      stashed=" ${number_of_stashes##*(  )}≡"
      bgclr='207'
      fgclr='232'
    fi

    if [[ $number_added -gt 0 || $number_added_modified -gt 0 || $number_added_deleted -gt 0 ]]; then ready_commit=' ⚑'; fi

    local upstream_prompt=''
    if [[ $has_upstream == true ]]; then
      commits_diff="$(git log --pretty=oneline --topo-order --left-right ${current_commit_hash}...${upstream} 2>/dev/null)"
      commits_ahead=$(\grep -c "^<" <<<"$commits_diff")
      commits_behind=$(\grep -c "^>" <<<"$commits_diff")
      upstream_prompt="$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2>/dev/null)"
      upstream_prompt=$(sed -e 's/\/.*$/ ☊ /g' <<<"$upstream_prompt")
    fi

    has_diverged=false
    if [[ $commits_ahead -gt 0 && $commits_behind -gt 0 ]]; then has_diverged=true; fi
    if [[ $has_diverged == false && $commits_ahead -gt 0 ]]; then
      to_push=" $fg[232]↑$commits_ahead$fg[$fgclr]"
    fi
    if [[ $has_diverged == false && $commits_behind -gt 0 ]]; then to_pull=" $fg[207]↓$commits_behind$fg[$fgclr]"; fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    prompt_segment $bgclr $fgclr

    print -n "%{$fg[$fgclr]%}${ref/refs\/heads\//$PL_BRANCH_CHAR$upstream_prompt}${mode}$to_push$to_pull$clean$tagged$stashed$untracked$modified$deleted$added$ready_commit%{$fg_no_bold[$fgclr]%}"
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment "238" "231" "%~"
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{197}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{226}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{159}%}$GEAR"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_temperature() {
  local temp_raw=$(sensors | grep temp1: | cut -d"+" -f2)
  local trimed=$(echo "$temp_raw" | xargs)
  local temperature_formatted=$(echo "${trimed// C/°C}")
  local temperature=$(echo "${trimed// C/}")
  local temperature_int="${temperature%%.*}"
  local fg_color="231"

  local bg_color="039"
  if [ $temperature_int -gt 70 ]; then
    bg_color="202"
  elif [ $temperature_int -gt 50 ]; then
    bg_color="220"
  fi

  prompt_segment $bg_color "232" "CPU: $temperature_formatted%{$fg_no_bold[white]%}"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  print -n "\n"
  prompt_temperature
  prompt_status
  prompt_dir
  prompt_git
  prompt_end
  CURRENT_BG='NONE'
  print -n "\n"
  prompt_context
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
