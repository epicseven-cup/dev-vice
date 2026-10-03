# digivice: a prompt-embeddable branch-status indicator, in the same
# spirit as Oh My Zsh's git plugin's `git_prompt_info` - add
# $(digivice_prompt_info) to your PROMPT/RPROMPT (requires
# `setopt PROMPT_SUBST`, which Oh My Zsh enables by default) and it
# shows a small colored icon next to your prompt whenever the current
# branch is out of date, recomputed fresh on every prompt render:
#
#   ⬇3        behind its own upstream by 3 commits
#   ⬆2        ahead of its own upstream by 2 commits
#   ⬍1/2      diverged from its own upstream (behind 1, ahead 2)
#   ⟲5        behind the repo's base branch (e.g. origin/main) by 5
#             commits and should probably be rebased - shown even if
#             the branch has no upstream of its own
#
# Nothing is printed and no icon function needs to run when outside a
# git repo, or when the branch is fully up to date - digivice_prompt_info
# just returns an empty string.
#
# All of this only compares against whatever remote-tracking info is
# already known locally (same as `git status`) - it never fetches on
# its own, so it's instant. To keep that from going stale, entering a
# repo (on cd, or at shell startup if already inside one - once per
# repo per shell, not on every cd within it) can also kick off a
# `git fetch --all` in the background. This is opt-in: the first time
# a repo is found out of date and no preference has been recorded,
# you're asked (only in an interactive terminal) whether digivice
# should keep that repo fresh automatically from then on. The answer
# is remembered per-repo in .git/digivice_autofetch. If enabled, the
# background fetch is throttled to at most once per repo per
# DIGIVICE_FETCH_THROTTLE_SECONDS (default 5 minutes).

typeset -g _DIGIVICE_LAST_GIT_TOPLEVEL=""
typeset -g DIGIVICE_FETCH_THROTTLE_SECONDS=${DIGIVICE_FETCH_THROTTLE_SECONDS:-300}

_digivice_autofetch_pref_file() {
  echo "$1/.git/digivice_autofetch"
}

_digivice_autofetch_enabled() {
  local pref_file="$(_digivice_autofetch_pref_file "$1")"
  [[ -f "$pref_file" && "$(<"$pref_file")" == "yes" ]]
}

# Ask (once, interactively only) whether to enable continuous
# auto-fetch for this repo. Only called when the repo is already
# known to be out of date, and only if no preference is saved.
_digivice_maybe_prompt_autofetch() {
  local toplevel="$1"
  local pref_file="$(_digivice_autofetch_pref_file "$toplevel")"

  [[ -f "$pref_file" ]] && return
  [[ -t 0 && -t 1 ]] || return

  if read -q "REPLY?   Keep this repo's remote info fresh automatically from now on (fetch in background on entry)? [y/N] "; then
    echo "yes" > "$pref_file"
  else
    echo "no" > "$pref_file"
  fi
  echo
}

_digivice_maybe_background_fetch() {
  local toplevel="$1"
  _digivice_autofetch_enabled "$toplevel" || return
  git remote 2>/dev/null | read -r _ || return

  local stamp_file="$toplevel/.git/digivice_last_fetch"
  local now last=0
  now=$(date +%s)
  [[ -f "$stamp_file" ]] && last=$(<"$stamp_file")

  if (( now - last < DIGIVICE_FETCH_THROTTLE_SECONDS )); then
    return
  fi
  echo "$now" > "$stamp_file"
  ( cd "$toplevel" && git fetch -q --all ) &>/dev/null &!
}

# repo's base branch, e.g. "main" or "master" - same logic as gmain
_digivice_base_branch() {
  local base
  base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [[ -z "$base" ]]; then
    git show-ref --verify --quiet refs/remotes/origin/main && base=main
    [[ -z "$base" ]] && git show-ref --verify --quiet refs/remotes/origin/master && base=master
  fi
  echo "$base"
}

# echoes "<behind> <ahead> <base_behind>" for the current branch -
# <behind>/<ahead> relative to its own @{upstream} (0/0 if it has
# none), <base_behind> relative to the repo's base branch (0 if none
# found, or if that base branch IS the upstream already compared
# above). Local refs only - never fetches. Assumes the caller already
# verified the cwd is inside a git repo.
_digivice_branch_counts() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || { echo "0 0 0"; return; }

  local upstream behind=0 ahead=0
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)
  if [[ -n "$upstream" ]]; then
    local counts
    counts=$(git rev-list --left-right --count "${upstream}...${branch}" 2>/dev/null)
    if [[ -n "$counts" ]]; then
      behind="${counts%%$'\t'*}"
      ahead="${counts##*$'\t'}"
    fi
  fi

  local base_behind=0
  local base_branch
  base_branch=$(_digivice_base_branch)
  if [[ -n "$base_branch" && "$branch" != "$base_branch" ]]; then
    local base_ref="origin/$base_branch"
    if [[ "$base_ref" != "$upstream" ]]; then
      base_behind=$(git rev-list --count "${branch}..${base_ref}" 2>/dev/null)
      [[ -z "$base_behind" ]] && base_behind=0
    fi
  fi

  echo "$behind $ahead $base_behind"
}

# call this from your PROMPT/RPROMPT, e.g.:
#   PROMPT='%~ $(digivice_prompt_info) %# '
# (needs `setopt PROMPT_SUBST`, on by default under Oh My Zsh)
digivice_prompt_info() {
  git rev-parse --is-inside-work-tree &>/dev/null || return

  local behind ahead base_behind
  read -r behind ahead base_behind <<<"$(_digivice_branch_counts)"

  local out=""
  if (( behind > 0 && ahead > 0 )); then
    out="%F{red}⬍${behind}/${ahead}%f"
  elif (( behind > 0 )); then
    out="%F{yellow}⬇${behind}%f"
  elif (( ahead > 0 )); then
    out="%F{green}⬆${ahead}%f"
  fi

  if (( base_behind > 0 )); then
    [[ -n "$out" ]] && out+=" "
    out+="%F{cyan}⟲${base_behind}%f"
  fi

  [[ -n "$out" ]] && print -n -- "$out"
}

_digivice_check_branch_status() {
  local toplevel
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -z "$toplevel" ]]; then
    _DIGIVICE_LAST_GIT_TOPLEVEL=""
    return
  fi

  if [[ "$toplevel" == "$_DIGIVICE_LAST_GIT_TOPLEVEL" ]]; then
    return
  fi
  _DIGIVICE_LAST_GIT_TOPLEVEL="$toplevel"

  _digivice_maybe_background_fetch "$toplevel"

  local behind ahead base_behind
  read -r behind ahead base_behind <<<"$(_digivice_branch_counts)"
  if (( behind > 0 || base_behind > 0 )); then
    _digivice_maybe_prompt_autofetch "$toplevel"
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _digivice_check_branch_status
_digivice_check_branch_status
