# dev-vice: suggests updating itself, and provides `dev-vice-update`
# to actually do it.
#
# At shell startup (once, not on every cd), checks whether this
# plugin's own clone is behind its origin - using only already-known
# local info (instant, same approach as dev_vice_prompt_info). If so,
# prints a one-line suggestion to stderr. This also kicks off a
# throttled background `git fetch` of the plugin's own repo (default:
# once per day, DEVVICE_SELF_FETCH_THROTTLE_SECONDS) so that
# comparison stays reasonably fresh over time - this is dev-vice's
# own repo, not one of your projects, so unlike the per-project
# autofetch it's on by default (set DEVVICE_SELF_UPDATE_CHECK=0
# before the plugin loads to turn it off entirely).

typeset -g DEVVICE_SELF_UPDATE_CHECK=${DEVVICE_SELF_UPDATE_CHECK:-1}
typeset -g DEVVICE_SELF_FETCH_THROTTLE_SECONDS=${DEVVICE_SELF_FETCH_THROTTLE_SECONDS:-86400}

# pulls the latest dev-vice from its own origin.
dev-vice-update() {
  if ! git -C "$DEVVICE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "dev-vice-update: $DEVVICE_DIR isn't a git repo - reinstall dev-vice via git clone" >&2
    return 1
  fi

  echo "Updating dev-vice..."
  if git -C "$DEVVICE_DIR" pull --ff-only; then
    echo "✅ dev-vice updated - restart your shell (or run: exec zsh) to pick up changes"
  else
    echo "⚠️  dev-vice-update: pull failed - resolve manually in $DEVVICE_DIR" >&2
    return 1
  fi
}

_devvice_self_update_check() {
  [[ "$DEVVICE_SELF_UPDATE_CHECK" == 1 ]] || return
  git -C "$DEVVICE_DIR" rev-parse --is-inside-work-tree &>/dev/null || return

  local stamp_file="$DEVVICE_DIR/.git/devvice_self_fetch"
  local now last=0
  now=$(date +%s)
  [[ -f "$stamp_file" ]] && last=$(<"$stamp_file")
  if (( now - last >= DEVVICE_SELF_FETCH_THROTTLE_SECONDS )); then
    echo "$now" > "$stamp_file"
    ( git -C "$DEVVICE_DIR" fetch -q origin ) &>/dev/null &!
  fi

  local branch upstream
  branch=$(git -C "$DEVVICE_DIR" symbolic-ref --short HEAD 2>/dev/null) || return
  upstream=$(git -C "$DEVVICE_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || return

  local behind
  behind=$(git -C "$DEVVICE_DIR" rev-list --count "${branch}..${upstream}" 2>/dev/null)
  if [[ -n "$behind" && "$behind" -gt 0 ]]; then
    echo "💡 dev-vice: $behind update(s) available - run 'dev-vice-update' to get them" >&2
  fi
}

_devvice_self_update_check
