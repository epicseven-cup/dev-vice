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
_run() {
  zsh -c "source '$DIGIVICE_PLUGIN'; eval ${(qqq)1}"
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
  local out
  out=$(_run "cd '$DIGIVICE_PROJECT_ROOT' && gs >/dev/null; type gs")
  assert_contains "$out" "lib/git.zsh" "gs should be the real function after being called once"
}

test_loading_one_git_command_upgrades_the_whole_module() {
  local out
  out=$(_run "cd '$DIGIVICE_PROJECT_ROOT' && gs >/dev/null; type gmain")
  assert_contains "$out" "lib/git.zsh" "calling gs should also resolve gmain's stub (same module)"
}

test_unrelated_modules_stay_lazy() {
  local out
  out=$(_run "cd '$DIGIVICE_PROJECT_ROOT' && gs >/dev/null; type drun")
  assert_contains "$out" "digivice.plugin.zsh" "drun (node module) should remain a stub after a git command runs"
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
