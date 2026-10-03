# digivice: tab-completion suggestions for gcm's Conventional Commits
# type (https://www.conventionalcommits.org/) and gcb's branch-name
# prefixes. Loaded eagerly (completion needs to be registered before
# gcm/gcb are ever called, and it's cheap) but only if the zsh
# completion system (compinit) is already active - Oh My Zsh loads it
# before sourcing plugins, but a bare `zsh -c` test environment won't
# have it, so this degrades to a no-op rather than erroring.

_digivice_gcm_types() {
  local -a types
  types=(
    'feat:A new feature'
    'fix:A bug fix'
    'docs:Documentation only changes'
    'style:Formatting, missing semicolons, etc (no code meaning change)'
    'refactor:Neither fixes a bug nor adds a feature'
    'perf:A performance improvement'
    'test:Adding or correcting tests'
    'build:Changes to the build system or external dependencies'
    'ci:Changes to CI configuration files and scripts'
    'chore:Other changes that do not modify src or test files'
    'revert:Reverts a previous commit'
  )
  _describe -t commit-types 'conventional commit type' types
}

_digivice_gcb_prefixes() {
  local -a prefixes
  prefixes=(
    'feature/:New feature or requirement'
    'feat/:New feature or requirement (short form)'
    'bugfix/:Routine bug fix tied to a development cycle'
    'fix/:Routine bug fix (short form)'
    'hotfix/:Critical patch bypassing the normal release schedule'
    'chore/:Technical debt, dependency updates, config changes, cleanups'
    'refactor/:Technical debt or cleanup (short form)'
    'docs/:Documentation, readmes, or wikis'
  )
  _describe -t branch-prefixes 'branch prefix' prefixes -S ''
}

# completer for plain `git`: offers the same branch-prefix
# suggestions as gcb for `git checkout -b <TAB>` (or `git switch -c
# <TAB>`), the same commit-type suggestions as gcm for
# `git commit -m <TAB>` (also -am, --message, or any short flag
# combo ending in m), and otherwise falls through to the normal
# `_git` completer so every other git subcommand completes exactly
# as it always did.
_digivice_git() {
  local subcmd="${words[2]}" prevword="${words[CURRENT-1]}"
  if { [[ "$subcmd" == "checkout" && "$prevword" == "-b" ]] ||
       [[ "$subcmd" == "switch" && "$prevword" == "-c" ]]; }; then
    _digivice_gcb_prefixes
    return
  fi
  if [[ "$subcmd" == "commit" ]]; then
    case "$prevword" in
      -m|--message|-*m)
        _digivice_gcm_types
        return
        ;;
    esac
  fi
  (( $+functions[_git] )) && _git
}

if (( $+functions[compdef] )); then
  compdef _digivice_gcm_types gcm
  compdef _digivice_gcb_prefixes gcb
  compdef _digivice_git git

  # color digivice's own completion suggestions: candidate text in
  # cyan, group headers (e.g. "-- conventional commit type --") in
  # green. Scoped to the gcm/gcb/git commands only, so other
  # completions elsewhere in the shell are left at the user's normal
  # colors (git's own non-branch-prefix completions included, since
  # _digivice_git delegates those straight to the real _git).
  zstyle ':completion:*:*:(gcm|gcb):*' list-colors '=(#b)(*)=36'
  zstyle ':completion:*:*:(gcm|gcb):*:descriptions' format $'\e[32m-- %d --\e[0m'
  # for plain `git`, scope value coloring to just our own tags
  # (branch-prefixes, commit-types) so _git's own (delegated)
  # completions keep their normal colors
  zstyle ':completion:*:*:git:*:(branch-prefixes|commit-types)' list-colors '=(#b)(*)=36'
  zstyle ':completion:*:*:git:*:descriptions' format $'\e[32m-- %d --\e[0m'
fi
