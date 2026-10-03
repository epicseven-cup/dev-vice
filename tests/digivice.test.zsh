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
# command runs its own `cd`. stdin is /dev/null so this never has a
# tty - the autofetch opt-in prompt must never fire (and never hang)
# under test.
_run() {
  zsh -c "cd /tmp && source '$DIGIVICE_PLUGIN'; eval ${(qqq)1}" < /dev/null
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

test_gcb_creates_and_checks_out_new_branch() {
  local tmp="$(mktemp -d)"
  (cd "$tmp" && git init -q -b main . && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init)
  local out
  out=$(_run "cd '$tmp' && gcb feature/new-thing >/dev/null 2>&1; git branch --show-current")
  assert_eq "feature/new-thing" "$out" "gcb should create and check out the new branch"
  rm -rf "$tmp"
}

# --- gcm Conventional Commits shorthand -------------------------------------

test_gcm_expands_shorthand_type() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && gcm 'ft: add a' >/dev/null && git log -1 --format=%s")
  assert_eq "feat: add a" "$out" "gcm should expand the 'ft' shorthand to 'feat'"
  rm -rf "$tmp"
}

test_gcm_expands_shorthand_with_scope_and_breaking_marker() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && gcm 'fx(core)!: fix a' >/dev/null && git log -1 --format=%s")
  assert_eq "fix(core)!: fix a" "$out" "gcm should expand shorthand while preserving scope and the breaking-change marker"
  rm -rf "$tmp"
}

test_gcm_leaves_full_conventional_type_unchanged() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && gcm 'docs: add a' >/dev/null && git log -1 --format=%s")
  assert_eq "docs: add a" "$out" "a message already using a full conventional type should pass through unchanged"
  rm -rf "$tmp"
}

test_gcm_leaves_unrecognized_prefix_unchanged() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && gcm 'random: add a' >/dev/null && git log -1 --format=%s")
  assert_eq "random: add a" "$out" "an unrecognized prefix should not be rewritten"
  rm -rf "$tmp"
}

test_gcm_leaves_plain_message_unchanged() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && gcm 'just a message' >/dev/null && git log -1 --format=%s")
  assert_eq "just a message" "$out" "a message with no colon should pass through unchanged"
  rm -rf "$tmp"
}

test_gcm_all_documented_shorthands_expand_correctly() {
  # exercises every entry in DIGIVICE_COMMIT_TYPE_ALIASES directly
  # (no git commit needed) - catches a typo in the table itself, not
  # just the one or two shorthands spot-checked above.
  local pairs="ft:feat fx:fix dc:docs sty:style rf:refactor pf:perf ts:test bd:build ch:chore rv:revert"
  local pair short full out
  for pair in ${=pairs}; do
    short="${pair%%:*}"
    full="${pair#*:}"
    # `gs 2>/dev/null` just forces git.zsh to load (defining
    # _digivice_expand_commit_type) before calling it directly
    out=$(_run "gs >/dev/null 2>&1; _digivice_expand_commit_type '${short}: msg'")
    assert_eq "${full}: msg" "$out" "shorthand '$short' should expand to '$full'"
  done
}

test_gcm_completion_registers_with_compdef_when_available() {
  local out
  out=$(zsh -c "autoload -Uz compinit && compinit -D 2>/dev/null; source '$DIGIVICE_PLUGIN'; echo \${_comps[gcm]:-NOT-REGISTERED}" < /dev/null)
  assert_eq "_digivice_gcm_types" "$out" "gcm's completion function should register via compdef when compinit is active"
}

test_gcm_completion_setup_is_a_noop_without_compinit() {
  local out
  out=$(_run ': 2>&1')
  assert_true "$?" "sourcing the plugin should not error when compdef/compinit isn't available"
}

test_gcb_completion_registers_with_compdef_when_available() {
  local out
  out=$(zsh -c "autoload -Uz compinit && compinit -D 2>/dev/null; source '$DIGIVICE_PLUGIN'; echo \${_comps[gcb]:-NOT-REGISTERED}" < /dev/null)
  assert_eq "_digivice_gcb_prefixes" "$out" "gcb's completion function should register via compdef when compinit is active"
}

test_git_completion_registers_with_compdef_when_available() {
  local out
  out=$(zsh -c "autoload -Uz compinit && compinit -D 2>/dev/null; source '$DIGIVICE_PLUGIN'; echo \${_comps[git]:-NOT-REGISTERED}" < /dev/null)
  assert_eq "_digivice_git" "$out" "git's completion function should register via compdef when compinit is active"
}

# --- plain `git` wrapper (same Conventional Commits expansion as gcm) ------

test_plain_git_commit_dash_m_expands_shorthand() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && git commit -m 'ft: add a' >/dev/null && git log -1 --format=%s")
  assert_eq "feat: add a" "$out" "plain 'git commit -m' should get the same shorthand expansion as gcm"
  rm -rf "$tmp"
}

test_plain_git_commit_dash_am_expands_shorthand() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && git commit -q -m init && echo x >> a && git commit -am 'fx: tweak a' >/dev/null && git log -1 --format=%s")
  assert_eq "fix: tweak a" "$out" "'git commit -am' should also get shorthand expansion"
  rm -rf "$tmp"
}

test_plain_git_commit_message_equals_expands_shorthand() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && git commit --message='dc: add a' >/dev/null && git log -1 --format=%s")
  assert_eq "docs: add a" "$out" "'git commit --message=...' should also get shorthand expansion"
  rm -rf "$tmp"
}

test_plain_git_other_subcommands_are_unaffected() {
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  local out
  out=$(_run "cd '$tmp' && touch a && git add a && git status --short")
  assert_eq "A  a" "$out" "the git wrapper should leave non-commit subcommands completely untouched"
  rm -rf "$tmp"
}

# --- gcanrebase -------------------------------------------------------------

test_gcanrebase_reports_clean_when_no_conflicts() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (
    cd "$work" &&
    echo "line1" > fileA.txt && git add fileA.txt && git -c user.email=t@t.com -c user.name=t commit -q -m init &&
    git push -q -u origin HEAD:main &&
    git checkout -q -b feature &&
    echo "feature" > fileB.txt && git add fileB.txt && git -c user.email=t@t.com -c user.name=t commit -q -m feature &&
    git checkout -q main &&
    echo "mainchange" > fileC.txt && git add fileC.txt && git -c user.email=t@t.com -c user.name=t commit -q -m mainchange &&
    git push -q origin HEAD:main &&
    git checkout -q feature &&
    git fetch -q origin
  )
  local out
  out=$(_run "cd '$work' && gcanrebase"); local rc=$?
  assert_contains "$out" "can be rebased onto 'origin/main' cleanly" "should report a clean rebase when there's no conflict"
  assert_true "$rc" "gcanrebase should exit 0 when the rebase would be clean"
  assert_eq "feature" "$(git -C "$work" branch --show-current)" "the real worktree's branch should be untouched"
  assert_eq "" "$(git -C "$work" status --short)" "the real worktree should remain clean"
  assert_eq "1" "$(git -C "$work" worktree list | wc -l | tr -d ' ')" "no stray worktrees should be left behind"
  rm -rf "$bare" "$work"
}

test_gcanrebase_reports_conflict_and_leaves_repo_clean() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (
    cd "$work" &&
    echo "line1" > shared.txt && git add shared.txt && git -c user.email=t@t.com -c user.name=t commit -q -m init &&
    git push -q -u origin HEAD:main &&
    git checkout -q -b feature &&
    echo "feature-edit" > shared.txt && git add shared.txt && git -c user.email=t@t.com -c user.name=t commit -q -m feature-edit &&
    git checkout -q main &&
    echo "main-edit" > shared.txt && git add shared.txt && git -c user.email=t@t.com -c user.name=t commit -q -m main-edit &&
    git push -q origin HEAD:main &&
    git checkout -q feature &&
    git fetch -q origin
  )
  local out
  out=$(_run "cd '$work' && gcanrebase"); local rc=$?
  assert_contains "$out" "cannot be cleanly rebased onto 'origin/main'" "should report conflicts when the rebase would hit them"
  assert_false "$rc" "gcanrebase should exit non-zero when the rebase would conflict"
  assert_eq "feature" "$(git -C "$work" branch --show-current)" "the real worktree's branch should be untouched after a conflicting trial"
  assert_eq "" "$(git -C "$work" status --short)" "the real worktree should remain clean after a conflicting trial"
  assert_false "$([[ -d "$work/.git/rebase-merge" ]] && echo 0 || echo 1)" "no leftover rebase-merge state in the real repo"
  rm -rf "$bare" "$work"
}

test_gcanrebase_defaults_to_the_base_branch() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (
    cd "$work" &&
    git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init &&
    git push -q -u origin HEAD:main
  )
  local out
  out=$(_run "cd '$work' && gcanrebase" 2>&1)
  assert_contains "$out" "onto 'origin/main'" "with no argument, gcanrebase should default to the repo's base branch"
  rm -rf "$bare" "$work"
}

test_gcanrebase_errors_on_unknown_ref() {
  local tmp="$(mktemp -d)"
  (cd "$tmp" && git init -q -b main . && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init)
  local out
  out=$(_run "cd '$tmp' && gcanrebase nonexistent-ref" 2>&1)
  assert_contains "$out" "unknown ref" "gcanrebase should error on a nonexistent target ref"
  rm -rf "$tmp"
}

# --- github workflow scaffolding --------------------------------------------

test_ghwfnew_creates_node_workflow() {
  local tmp="$(mktemp -d)"
  echo '{}' > "$tmp/package.json"
  local out
  out=$(_run "cd '$tmp' && ghwfnew")
  assert_contains "$out" "created .github/workflows/ci.yml" "should report the file it created"
  assert_contains "$(<"$tmp/.github/workflows/ci.yml")" "setup-node" "a package.json should select the node template"
  rm -rf "$tmp"
}

test_ghwfnew_creates_python_workflow() {
  local tmp="$(mktemp -d)"
  echo 'flask' > "$tmp/requirements.txt"
  _run "cd '$tmp' && ghwfnew" >/dev/null
  assert_contains "$(<"$tmp/.github/workflows/ci.yml")" "setup-python" "a requirements.txt should select the python template"
  rm -rf "$tmp"
}

test_ghwfnew_creates_generic_workflow_otherwise() {
  local tmp="$(mktemp -d)"
  _run "cd '$tmp' && ghwfnew myci" >/dev/null
  assert_contains "$(<"$tmp/.github/workflows/myci.yml")" "add your build/test commands here" "no recognized project files should fall back to the generic template"
  rm -rf "$tmp"
}

test_ghwfnew_refuses_to_overwrite_existing_file() {
  local tmp="$(mktemp -d)"
  mkdir -p "$tmp/.github/workflows"
  echo "existing content" > "$tmp/.github/workflows/ci.yml"
  local out
  out=$(_run "cd '$tmp' && ghwfnew" 2>&1); local rc=$?
  assert_contains "$out" "already exists" "ghwfnew should refuse to overwrite an existing workflow file"
  assert_false "$rc" "ghwfnew should exit non-zero when the file already exists"
  assert_eq "existing content" "$(<"$tmp/.github/workflows/ci.yml")" "the existing file should be left untouched"
  rm -rf "$tmp"
}

test_ghwfls_lists_workflow_files() {
  local tmp="$(mktemp -d)"
  mkdir -p "$tmp/.github/workflows"
  touch "$tmp/.github/workflows/ci.yml" "$tmp/.github/workflows/lint.yml"
  local out
  out=$(_run "cd '$tmp' && ghwfls")
  assert_contains "$out" "ci.yml" "ghwfls should list existing workflow files"
  assert_contains "$out" "lint.yml" "ghwfls should list existing workflow files"
  rm -rf "$tmp"
}

test_ghwfls_errors_without_workflows_directory() {
  local tmp="$(mktemp -d)"
  local out
  out=$(_run "cd '$tmp' && ghwfls" 2>&1)
  assert_contains "$out" "no .github/workflows directory" "ghwfls should error when there's no workflows directory"
  rm -rf "$tmp"
}

test_ghwfedit_opens_the_workflow_file_in_editor() {
  local tmp="$(mktemp -d)"
  mkdir -p "$tmp/.github/workflows"
  touch "$tmp/.github/workflows/ci.yml"
  local fakebin="$(mktemp -d)"
  cat > "$fakebin/fakeeditor" <<'EOF'
#!/bin/sh
echo "opened: $1"
EOF
  chmod +x "$fakebin/fakeeditor"
  local out
  out=$(_run "export EDITOR='$fakebin/fakeeditor' && cd '$tmp' && ghwfedit ci")
  assert_eq "opened: .github/workflows/ci.yml" "$out" "ghwfedit should invoke \$EDITOR with the workflow file's path"
  rm -rf "$tmp" "$fakebin"
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

# --- digivice_prompt_info ---------------------------------------------------

test_prompt_info_silent_outside_a_git_repo() {
  local tmp="$(mktemp -d)"
  local out
  out=$(_run "cd '$tmp' && digivice_prompt_info")
  assert_eq "" "$out" "no git repo should mean no prompt info output"
  rm -rf "$tmp"
}

test_prompt_info_silent_when_up_to_date() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  local out
  out=$(_run "cd '$work' && digivice_prompt_info")
  assert_eq "" "$out" "a branch in sync with its upstream should produce no prompt info"
  rm -rf "$bare" "$work"
}

test_prompt_info_shows_behind_count() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  local out
  out=$(_run "cd '$work' && digivice_prompt_info")
  assert_eq "%F{yellow}⬇1%f" "$out" "should show a yellow behind-count icon"
  rm -rf "$bare" "$work" "$other"
}

test_prompt_info_shows_ahead_count() {
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
  out=$(_run "cd '$work' && digivice_prompt_info")
  assert_eq "%F{green}⬆1%f" "$out" "should show a green ahead-count icon"
  rm -rf "$bare" "$work"
}

test_prompt_info_shows_diverged() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m local-only)
  local out
  out=$(_run "cd '$work' && digivice_prompt_info")
  assert_eq "%F{red}⬍1/1%f" "$out" "should show a red diverged icon with behind/ahead counts"
  rm -rf "$bare" "$work" "$other"
}

test_prompt_info_recomputes_on_every_call() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  mkdir -p "$work/subdir"
  local out
  out=$(_run "cd '$work' && cd subdir && cd .. && digivice_prompt_info")
  assert_eq "%F{yellow}⬇1%f" "$out" "unlike the old chpwd-only check, prompt info must reflect the current state on every call"
  rm -rf "$bare" "$work" "$other"
}

# --- autofetch opt-in -------------------------------------------------------

test_autofetch_prompt_skipped_and_undecided_without_a_tty() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  _run "cd '$work'" >/dev/null 2>&1
  assert_eq "0" "$([[ -f "$work/.git/digivice_autofetch" ]] && echo 1 || echo 0)" "no tty means no prompt, so no preference should be recorded"
  rm -rf "$bare" "$work" "$other"
}

test_autofetch_disabled_by_saved_no_preference() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  echo "no" > "$work/.git/digivice_autofetch"
  local out
  out=$(_run "cd '$work'" 2>&1)
  assert_eq "0" "$([[ -f "$work/.git/digivice_last_fetch" ]] && echo 1 || echo 0)" "a saved 'no' preference should skip the background fetch entirely"
  rm -rf "$bare" "$work" "$other"
}

test_autofetch_enabled_by_saved_yes_preference() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  echo "yes" > "$work/.git/digivice_autofetch"
  _run "cd '$work'" >/dev/null 2>&1
  assert_eq "1" "$([[ -f "$work/.git/digivice_last_fetch" ]] && echo 1 || echo 0)" "a saved 'yes' preference should trigger the background fetch"
  rm -rf "$bare" "$work" "$other"
}

test_autofetch_not_triggered_when_up_to_date_even_if_enabled() {
  local bare="$(mktemp -d)" work="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  echo "yes" > "$work/.git/digivice_autofetch"
  _run "cd '$work'" >/dev/null 2>&1
  # background fetch is gated on autofetch being enabled, independent of
  # whether the repo happens to be up to date - it should still run
  assert_eq "1" "$([[ -f "$work/.git/digivice_last_fetch" ]] && echo 1 || echo 0)" "enabled autofetch should run regardless of current up-to-date status"
  rm -rf "$bare" "$work"
}

# --- base-branch rebase check -----------------------------------------------

test_prompt_info_shows_rebase_icon_with_no_own_upstream() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  # feature branch forks right after init, before main advances further, and has no upstream of its own
  (cd "$work" && git checkout -q -b feature && git branch --unset-upstream)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  local out
  out=$(_run "cd '$work' && digivice_prompt_info")
  assert_eq "%F{cyan}⟲1%f" "$out" "a feature branch with no upstream should still show the base-branch rebase icon"
  rm -rf "$bare" "$work" "$other"
}

test_prompt_info_does_not_duplicate_when_upstream_is_base_branch() {
  local bare="$(mktemp -d)" work="$(mktemp -d)" other="$(mktemp -d)"
  git init -q --bare "$bare"
  git clone -q "$bare" "$work"
  (cd "$work" && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init && git push -q -u origin HEAD:main)
  git clone -q "$bare" "$other"
  (cd "$other" && git checkout -q main && git -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m second && git push -q origin HEAD:main)
  (cd "$work" && git fetch -q origin)
  local out
  out=$(_run "cd '$work' && digivice_prompt_info")
  assert_eq "%F{yellow}⬇1%f" "$out" "when the branch's own upstream is the base branch, only the behind icon should show (no separate rebase icon)"
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
