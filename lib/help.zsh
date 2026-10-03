# digivice: a single discoverable entry point. Run `digivice` (or
# `digivice help`) for a full command cheat-sheet; `digivice update`
# is a shortcut for `digivice-update`.

digivice-help() {
  cat <<'EOF'
digivice - zsh dev productivity plugin

GIT
  gs, ga, gaa, gc, gco, gb, gp, gpl, gl, gd, gds, gst, gstp   thin git aliases
  gcm <msg>         git commit -m, with Conventional Commits shorthand:
                    gcm 'ft: msg' -> commits as 'feat: msg' (also works
                    with plain `git commit -m`/-am/--message=). Tab-complete
                    the type with gcm <TAB> or git commit -m "<TAB>.
  gcb <name>        git checkout -b; tab-completes a branch-prefix
                    convention (feature/, bugfix/, hotfix/, chore/, docs/)
                    - also works with plain `git checkout -b`/`switch -c`.
  gmain             checkout the repo's default branch (main or master)
  gcanrebase [ref]  check whether rebasing onto ref (default: the repo's
                    base branch) would be conflict-free, without touching
                    your real working tree

NODE / PACKAGE MANAGERS
  ni, nr, nrs, nrb, nrt      npm install/run/start/build/test
  yi, yr                     yarn install/run
  pni, pnr                   pnpm install/run
  drun [script]              run a script (default: dev) with whichever
                              package manager this project uses

DOCKER
  dps, dpsa, dimg, dlog, dprune
  dsh <container>            exec a shell into a running container

GITHUB ACTIONS
  ghwfnew [name]    scaffold .github/workflows/<name>.yml (default: ci)
  ghwfls            list workflow files
  ghwfedit <name>   open a workflow file in $EDITOR

NAVIGATION
  .. ... ....       cd up 1/2/3 directories
  -                 cd to the previous directory

BRANCH STATUS
  digivice_prompt_info   add $(digivice_prompt_info) to your PROMPT to see
                          ⬇ behind / ⬆ ahead / ⬍ diverged / ⟲ needs-rebase
                          icons - see the README for the one-line setup.
  (the first time a repo is found out of date, you're asked whether to
  auto-fetch it in the background from then on)

UPDATING DIGIVICE ITSELF
  digivice update   (or digivice-update) pull the latest digivice - you're
                     notified automatically at shell startup when one's
                     available

Full details: https://github.com/epicseven-cup/digivice
EOF
}

digivice() {
  case "$1" in
    update)
      shift
      digivice-update "$@"
      ;;
    help|"")
      digivice-help
      ;;
    *)
      echo "digivice: unknown subcommand '$1' - try 'digivice help'" >&2
      return 1
      ;;
  esac
}
