# digivice: tests for digivice.plugin.zsh and its lib/ modules
#
# Each test runs the plugin in a fresh `zsh -c` subshell so tests never
# share state (loaded modules, cwd, PATH stubs) with each other.

# NOTE: ${0:A:h} only resolves to this file's directory right now, at
# source-time. Inside the test functions below, $0 has reverted to
# whatever it was before sourcing - so compute paths once here, not
# inside the functions that use them later.
DIGIVICE_TEST_DIR="${0:A:h}"
DIGIVICE_PROJECT_ROOT="${DIGIVICE_TEST_DIR}/.."
DIGIVICE_PLUGIN="${DIGIVICE_PROJECT_ROOT}/digivice.plugin.zsh"

# run zsh code with the plugin sourced first; prints stdout, exit code
# available via $? after the call.
#
# The command is run via `eval` so it is parsed at runtime, *after* the
# plugin has been sourced - mirroring real shell usage, where a user
# types a command on its own input line (parsed fresh) rather than in
# the same parse pass as the `source`. Without this, alias expansion
# (which happens at parse time, unlike function lookup) would not see
# aliases defined by the just-sourced plugin.
# start in /tmp (never a git repo) before sourcing, so the plugin's
# load-time branch-status check has nothing to report before the test
# command runs its own `cd`
_run() {
  zsh -c "cd /tmp && source '$DIGIVICE_PLUGIN'; eval ${(qqq)1}"
}

test_plugin_sources_without_error() {
  local out
  out=$(_run ': 2>&1')
  assert_true "$?" "plugin should source cleanly"
}

test_navigation_alias_changes_directory() {
  local out
  out=$(_run 'cd /tmp && .. && pwd')
  assert_eq "/" "$out" "'..' should cd up one directory"
}

test_git_command_starts_as_stub() {
  local out
  out=$(_run "type gs")
  assert_contains "$out" "digivice.plugin.zsh" "gs should initially be the lazy stub"
}

test_git_command_loads_real_function_on_first_call() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && gs >/dev/null; type gs")
  assert_contains "$out" "lib/git.zsh" "gs should be the real function after being called once"
  rm -rf "$tmp"
}

test_loading_one_git_command_upgrades_the_whole_module() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && gs >/dev/null; type gmain")
  assert_contains "$out" "lib/git.zsh" "calling gs should also resolve gmain's stub (same module)"
  rm -rf "$tmp"
}

test_unrelated_modules_stay_lazy() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && gs >/dev/null; type drun")
  assert_contains "$out" "digivice.plugin.zsh" "drun (node module) should remain a stub after a git command runs"
  rm -rf "$tmp"
}

test_gmain_fails_without_main_or_master_branch() {
  local tmp="$(mktemp -d)"
  (cd "$tmp" && git init -q -b weird-branch-name .)
  local out
  out=$(_run "cd '$tmp' && gmain" 2>&1)
  assert_contains "$out" "could not determine default branch" "gmain should error on an unrecognized default branch"
  rm -rf "$tmp"
}

test_gmain_checks_out_main() {
  local tmp="$(mktemp -d)"
  (
    cd "$tmp" && git init -q -b main . &&
    git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init &&
    git checkout -q -b feature
  )
  local out
  out=$(_run "cd '$tmp' && gmain >/dev/null 2>&1; git branch --show-current")
  assert_eq "main" "$out" "gmain should check out the main branch"
  rm -rf "$tmp"
}

test_dsh_requires_an_argument() {
  local out
  out=$(_run "dsh" 2>&1)
  assert_contains "$out" "usage: dsh" "dsh with no args should print usage and not call docker"
}

test_drun_errors_without_package_json() {
  local tmp="$(mktemp -d)"
  local out
  out=$(_run "cd '$tmp' && drun" 2>&1)
  assert_contains "$out" "no package.json found" "drun should error when no package.json/lockfile is present"
  rm -rf "$tmp"
}

test_branch_status_silent_outside_a_git_repo() {
  local tmp="$(mktemp -d)"
  local out
  out=$(_run "cd '$tmp'" 2>&1)
  assert_eq "" "$out" "no git repo should mean no branch-status output"
  rm -rf "$tmp"
}

test_branch_status_silent_when_up_to_date() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  local out
  out=$(_run "cd '$work'" 2>&1)
  assert_eq "" "$out" "a branch in sync with its upstream should print nothing"
  rm -rf "$bare" "$work"
}

test_branch_status_warns_when_behind() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  local out
  out=$(_run "cd '$work'" 2>&1)
  assert_contains "$out" "is behind 'origin/main' by 1 commit(s)" "should warn when the local branch is behind its upstream"
  rm -rf "$bare" "$work" "$other"
}

test_branch_status_notes_when_ahead() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (
    cd "$work" &&
    git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init &&
    git push -q -u origin HEAD:main &&
    git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m local-only
  )
  local out
  out=$(_run "cd '$work'" 2>&1)
  assert_contains "$out" "is ahead of 'origin/main' by 1 commit(s)" "should note when the local branch is ahead of its upstream"
  rm -rf "$bare" "$work"
}

test_branch_status_only_checks_once_per_repo() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  mkdir -p "$work/subdir"
  local out
  out=$(_run "cd '$work' && cd subdir && cd ..; : " 2>&1)
  local count
  count=$(print -r -- "$out" | grep -c "is behind")
  assert_eq "1" "$count" "cd'ing within the same repo should not re-print the warning"
  rm -rf "$bare" "$work" "$other"
}

test_drun_prefers_pnpm_lockfile() {
  local tmp="$(mktemp -d)"
  touch "$tmp/pnpm-lock.yaml"
  # stub pnpm on PATH so we can assert it was invoked, without requiring it installed
  local fakebin="$(mktemp -d)"
  cat > "$fakebin/pnpm" <<'EOF'
#!/bin/sh
echo "pnpm $*"
EOF
  chmod +x "$fakebin/pnpm"
  local out
  out=$(_run "export PATH='$fakebin:\$PATH' && cd '$tmp' && drun build")
  assert_eq "pnpm run build" "$out" "drun should delegate to pnpm when pnpm-lock.yaml is present"
  rm -rf "$tmp" "$fakebin"
}
