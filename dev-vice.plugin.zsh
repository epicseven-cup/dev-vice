# dev-vice - general dev productivity aliases & functions for Oh My Zsh
#
# Modules in lib/ are lazy-loaded: each command is registered as a stub
# function. The first time a command is actually run, its module is
# sourced (defining the real implementation for every command in that
# module) and the call is passed through. Subsequent calls hit the real
# function directly, with no further sourcing.

0=${(%):-%N}
DEVVICE_DIR=${0:A:h}

# navigation is just a handful of trivial aliases - load eagerly
source "$DEVVICE_DIR/lib/navigation.zsh"

# branch-status warnings need to run on every `cd` (via a chpwd hook),
# so this can't be lazy-loaded like the command modules below
source "$DEVVICE_DIR/lib/branch_status.zsh"

# completion needs to be registered against the gcm stub before gcm
# is ever called, so this can't be lazy-loaded either
source "$DEVVICE_DIR/lib/completions.zsh"

# self-update check needs to run once at shell startup, not lazily
source "$DEVVICE_DIR/lib/self_update.zsh"

# the `dev-vice` help/dispatch command is cheap and should always be
# available immediately, so it's eager too
source "$DEVVICE_DIR/lib/help.zsh"

typeset -gA DEVVICE_MODULE_CMDS
DEVVICE_MODULE_CMDS=(
  git    "git gs ga gaa gc gcm gco gcb gb gp gpl gl gd gds gst gstp gmain gcanrebase"
  node   "ni nr nrs nrb nrt yi yr pni pnr drun"
  docker "dps dpsa dimg dlog dprune dsh"
  github "ghwfnew ghwfls ghwfedit"
)

_devvice_make_stub() {
  local module="$1" cmd="$2"
  eval "function $cmd() {
    unfunction $cmd 2>/dev/null
    source '$DEVVICE_DIR/lib/$module.zsh'
    $cmd \"\$@\"
  }"
}

for module in ${(k)DEVVICE_MODULE_CMDS}; do
  for cmd in ${=DEVVICE_MODULE_CMDS[$module]}; do
    _devvice_make_stub "$module" "$cmd"
  done
done
unset module cmd
