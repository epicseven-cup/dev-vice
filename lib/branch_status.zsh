# digivice: warn in the terminal when the current repo's branch is
# out of date. Runs once per repo (on cd into it, or at shell startup
# if already inside one) - not on every cd within the same repo.
#
# Two independent checks:
#   1. current branch vs its own upstream (@{upstream}) - behind/
#      ahead/diverged.
#   2. current branch vs the repo's base branch (origin/main or
#      origin/master) - flags when a feature branch has fallen behind
#      main and should probably be rebased, regardless of whether it
#      has its own upstream configured.
#
# Both checks only compare against whatever remote-tracking info is
# already known locally (same as `git status`) - they never fetch.
# Auto-fetching is opt-in: the first time a repo is found to be behind
# and no preference has been recorded yet, the user is asked (only in
# an interactive terminal) whether digivice should keep that repo's
# remote-tracking info fresh automatically from now on. The answer is
# remembered per-repo in .git/digivice_autofetch. If enabled, repo
# entry kicks off a `git fetch --all` in the background (non-
# blocking), throttled to at most once per repo per
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
# auto-fetch for this repo. Only called after we've already shown the
# user a "you're behind" warning, and only if no preference is saved.
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

  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return

  local is_out_of_date=0
  local upstream
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)

  if [[ -n "$upstream" ]]; then
    local counts behind ahead
    counts=$(git rev-list --left-right --count "${upstream}...${branch}" 2>/dev/null)
    if [[ -n "$counts" ]]; then
      behind="${counts%%$'\t'*}"
      ahead="${counts##*$'\t'}"

      if [[ "$behind" -gt 0 && "$ahead" -gt 0 ]]; then
        echo "🔀 '$branch' has diverged from '$upstream' (ahead $ahead, behind $behind) - consider gpl --rebase" >&2
        is_out_of_date=1
      elif [[ "$behind" -gt 0 ]]; then
        echo "⚠️  '$branch' is behind '$upstream' by $behind commit(s) - run gpl to update" >&2
        is_out_of_date=1
      elif [[ "$ahead" -gt 0 ]]; then
        echo "⬆️  '$branch' is ahead of '$upstream' by $ahead commit(s) - run gp to push" >&2
      fi
    fi
  fi

  local base_branch
  base_branch=$(_digivice_base_branch)
  if [[ -n "$base_branch" && "$branch" != "$base_branch" ]]; then
    local base_ref="origin/$base_branch"
    if [[ "$base_ref" != "$upstream" ]]; then
      local base_behind
      base_behind=$(git rev-list --count "${branch}..${base_ref}" 2>/dev/null)
      if [[ -n "$base_behind" && "$base_behind" -gt 0 ]]; then
        echo "🔀 '$branch' is $base_behind commit(s) behind '$base_ref' - consider rebasing onto $base_branch" >&2
        is_out_of_date=1
      fi
    fi
  fi

  if [[ "$is_out_of_date" -eq 1 ]]; then
    _digivice_maybe_prompt_autofetch "$toplevel"
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _digivice_check_branch_status
_digivice_check_branch_status
