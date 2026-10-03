# digivice: suggests updating itself, and provides `digivice-update`
# to actually do it.
#
# At shell startup (once, not on every cd), checks whether this
# plugin's own clone is behind its origin - using only already-known
# local info (instant, same approach as digivice_prompt_info). If so,
# prints a one-line suggestion to stderr. This also kicks off a
# throttled background `git fetch` of the plugin's own repo (default:
# once per day, DIGIVICE_SELF_FETCH_THROTTLE_SECONDS) so that
# comparison stays reasonably fresh over time - this is digivice's
# own repo, not one of your projects, so unlike the per-project
# autofetch it's on by default (set DIGIVICE_SELF_UPDATE_CHECK=0
# before the plugin loads to turn it off entirely).

typeset -g DIGIVICE_SELF_UPDATE_CHECK=${DIGIVICE_SELF_UPDATE_CHECK:-1}
typeset -g DIGIVICE_SELF_FETCH_THROTTLE_SECONDS=${DIGIVICE_SELF_FETCH_THROTTLE_SECONDS:-86400}

# pulls the latest digivice from its own origin.
digivice-update() {
  if ! git -C "$DIGIVICE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "digivice-update: $DIGIVICE_DIR isn't a git repo - reinstall digivice via git clone" >&2
    return 1
  fi

  echo "Updating digivice..."
  if git -C "$DIGIVICE_DIR" pull --ff-only; then
    echo "✅ digivice updated - restart your shell (or run: exec zsh) to pick up changes"
  else
    echo "⚠️  digivice-update: pull failed - resolve manually in $DIGIVICE_DIR" >&2
    return 1
  fi
}

_digivice_self_update_check() {
  [[ "$DIGIVICE_SELF_UPDATE_CHECK" == 1 ]] || return
  git -C "$DIGIVICE_DIR" rev-parse --is-inside-work-tree &>/dev/null || return

  local stamp_file="$DIGIVICE_DIR/.git/digivice_self_fetch"
  local now last=0
  now=$(date +%s)
  [[ -f "$stamp_file" ]] && last=$(<"$stamp_file")
  if (( now - last >= DIGIVICE_SELF_FETCH_THROTTLE_SECONDS )); then
    echo "$now" > "$stamp_file"
    ( git -C "$DIGIVICE_DIR" fetch -q origin ) &>/dev/null &!
  fi

  local branch upstream
  branch=$(git -C "$DIGIVICE_DIR" symbolic-ref --short HEAD 2>/dev/null) || return
  upstream=$(git -C "$DIGIVICE_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || return

  local behind
  behind=$(git -C "$DIGIVICE_DIR" rev-list --count "${branch}..${upstream}" 2>/dev/null)
  if [[ -n "$behind" && "$behind" -gt 0 ]]; then
    echo "💡 digivice: $behind update(s) available - run 'digivice-update' to get them" >&2
  fi
}

_digivice_self_update_check
