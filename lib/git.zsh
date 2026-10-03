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
