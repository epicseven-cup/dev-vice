# digivice: warn in the terminal when the current repo's branch is
# out of date relative to its upstream. Runs once per repo (on cd into
# it, or at shell startup if already inside one) - not on every cd
# within the same repo, and never triggers a network fetch itself (it
# only compares against whatever remote-tracking info is already
# known locally, same as `git status`).

typeset -g _DIGIVICE_LAST_GIT_TOPLEVEL=""

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

  local branch upstream
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || return

  local counts behind ahead
  counts=$(git rev-list --left-right --count "${upstream}...${branch}" 2>/dev/null) || return
  behind="${counts%%$'\t'*}"
  ahead="${counts##*$'\t'}"

  if [[ "$behind" -gt 0 && "$ahead" -gt 0 ]]; then
    echo "digivice: '$branch' has diverged from '$upstream' (ahead $ahead, behind $behind) - consider gpl --rebase" >&2
  elif [[ "$behind" -gt 0 ]]; then
    echo "digivice: '$branch' is behind '$upstream' by $behind commit(s) - run gpl to update" >&2
  elif [[ "$ahead" -gt 0 ]]; then
    echo "digivice: '$branch' is ahead of '$upstream' by $ahead commit(s) - run gp to push" >&2
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _digivice_check_branch_status
_digivice_check_branch_status
