# digivice: git

gs() { git status "$@" }
ga() { git add "$@" }
gaa() { git add -A "$@" }
gc() { git commit -v "$@" }
gcm() { git commit -m "$@" }
gco() { git checkout "$@" }
gcb() { git checkout -b "$@" }
gb() { git branch "$@" }
gp() { git push "$@" }
gpl() { git pull "$@" }
gl() { git log --oneline --graph --decorate -20 "$@" }
gd() { git diff "$@" }
gds() { git diff --staged "$@" }
gst() { git stash "$@" }
gstp() { git stash pop "$@" }

# switch to the repo's default branch (main or master)
gmain() {
  local branch
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [[ -z "$branch" ]]; then
    git show-ref --verify --quiet refs/heads/main && branch=main
    [[ -z "$branch" ]] && git show-ref --verify --quiet refs/heads/master && branch=master
  fi
  if [[ -z "$branch" ]]; then
    echo "digivice: could not determine default branch" >&2
    return 1
  fi
  git checkout "$branch"
}

# check whether the current branch (or $1) could be rebased onto a
# target ref - default: the repo's base branch, e.g. origin/main -
# without hitting conflicts. Never touches your working tree, index,
# or uncommitted changes: it actually performs the rebase, but inside
# a disposable detached worktree that's discarded afterward either
# way. Exit status is 0 if the rebase would be clean, 1 otherwise.
gcanrebase() {
  local target="$1"
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
    echo "gcanrebase: not currently on a branch" >&2
    return 1
  }

  if [[ -z "$target" ]]; then
    local base
    base=$(_digivice_base_branch)
    if [[ -z "$base" ]]; then
      echo "gcanrebase: could not determine the base branch - pass one explicitly: gcanrebase <ref>" >&2
      return 1
    fi
    target="origin/$base"
  fi

  if ! git rev-parse --verify --quiet "$target" >/dev/null; then
    echo "gcanrebase: unknown ref '$target'" >&2
    return 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d) || return 1
  if ! git worktree add --detach -q "$tmpdir" "$branch" >/dev/null 2>&1; then
    echo "gcanrebase: could not create a scratch worktree to test the rebase" >&2
    rm -rf "$tmpdir"
    return 1
  fi

  local ok=0
  if git -C "$tmpdir" rebase "$target" >/dev/null 2>&1; then
    echo "✅ '$branch' can be rebased onto '$target' cleanly"
    ok=1
  else
    echo "⚠️  '$branch' cannot be cleanly rebased onto '$target' - conflicts expected"
    git -C "$tmpdir" rebase --abort >/dev/null 2>&1
  fi

  git worktree remove --force "$tmpdir" >/dev/null 2>&1
  rm -rf "$tmpdir"
  [[ "$ok" -eq 1 ]]
}
