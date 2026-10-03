# digivice - general dev productivity aliases & functions for Oh My Zsh
#
# Modules in lib/ are lazy-loaded: each command is registered as a stub
# function. The first time a command is actually run, its module is
# sourced (defining the real implementation for every command in that
# module) and the call is passed through. Subsequent calls hit the real
# function directly, with no further sourcing.

0=${(%):-%N}
DIGIVICE_DIR=${0:A:h}

# navigation is just a handful of trivial aliases - load eagerly
source "$DIGIVICE_DIR/lib/navigation.zsh"

# branch-status warnings need to run on every `cd` (via a chpwd hook),
# so this can't be lazy-loaded like the command modules below
source "$DIGIVICE_DIR/lib/branch_status.zsh"

typeset -gA DIGIVICE_MODULE_CMDS
DIGIVICE_MODULE_CMDS=(
  git    "gs ga gaa gc gcm gco gcb gb gp gpl gl gd gds gst gstp gmain gcanrebase"
  node   "ni nr nrs nrb nrt yi yr pni pnr drun"
  docker "dps dpsa dimg dlog dprune dsh"
)

_digivice_make_stub() {
  local module="$1" cmd="$2"
  eval "function $cmd() {
    unfunction $cmd 2>/dev/null
    source '$DIGIVICE_DIR/lib/$module.zsh'
    $cmd \"\$@\"
  }"
}

for module in ${(k)DIGIVICE_MODULE_CMDS}; do
  for cmd in ${=DIGIVICE_MODULE_CMDS[$module]}; do
    _digivice_make_stub "$module" "$cmd"
  done
done
unset module cmd
