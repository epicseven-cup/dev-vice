# digivice: warn in the terminal when the current repo's branch is
# out of date relative to its upstream. Runs once per repo (on cd into
# it, or at shell startup if already inside one) - not on every cd
# within the same repo.
#
# The check itself never fetches - it only compares against whatever
# remote-tracking info is already known locally (same as `git
# status`), so it's instant. To keep that info from going stale
# without you having to remember to run `git fetch` yourself, repo
# entry also kicks off a `git fetch` in the background (never
# blocking the shell), throttled to at most once per repo per
# DIGIVICE_FETCH_THROTTLE_SECONDS (default 5 minutes) using a
# timestamp file inside .git/ - so it won't hammer the remote or your
# network on every `cd`.

typeset -g _DIGIVICE_LAST_GIT_TOPLEVEL=""
typeset -g DIGIVICE_FETCH_THROTTLE_SECONDS=${DIGIVICE_FETCH_THROTTLE_SECONDS:-300}

_digivice_maybe_background_fetch() {
  local toplevel="$1"
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

  local branch upstream
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || return

  local counts behind ahead
  counts=$(git rev-list --left-right --count "${upstream}...${branch}" 2>/dev/null) || return
  behind="${counts%%$'\t'*}"
  ahead="${counts##*$'\t'}"

  if [[ "$behind" -gt 0 && "$ahead" -gt 0 ]]; then
    echo "🔀 '$branch' has diverged from '$upstream' (ahead $ahead, behind $behind) - consider gpl --rebase" >&2
  elif [[ "$behind" -gt 0 ]]; then
    echo "⚠️  '$branch' is behind '$upstream' by $behind commit(s) - run gpl to update" >&2
  elif [[ "$ahead" -gt 0 ]]; then
    echo "⬆️  '$branch' is ahead of '$upstream' by $ahead commit(s) - run gp to push" >&2
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _digivice_check_branch_status
_digivice_check_branch_status
