# digivice

An [Oh My Zsh](https://ohmyz.sh/) plugin with general dev productivity aliases and functions: git, npm/yarn/pnpm, docker, and navigation shortcuts.

## Installation

Clone this repo into your Oh My Zsh custom plugins directory:

```sh
git clone https://github.com/<your-username>/digivice.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/digivice"
```

Then add `digivice` to the `plugins=(...)` list in your `~/.zshrc`:

```sh
plugins=(... digivice)
```

Reload your shell:

```sh
source ~/.zshrc
```

## Structure

```
digivice.plugin.zsh   # entry point, sources everything in lib/
lib/
  navigation.zsh      # cd shortcuts
  branch_status.zsh    # out-of-date branch warnings (chpwd hook)
  git.zsh              # git aliases + gmain
  node.zsh             # npm/yarn/pnpm aliases + drun
  docker.zsh           # docker aliases + dsh
```

Commands are lazy-loaded: `git.zsh`, `node.zsh`, and `docker.zsh` are not sourced at shell startup. Instead each command they provide (`gs`, `drun`, `dsh`, etc.) is registered as a lightweight stub. The first time you actually run one, its module is sourced (defining every real function in that module) and the call is passed through — later calls hit the real function directly, with no extra `source` cost. `navigation.zsh` and `branch_status.zsh` are small/need to run unconditionally, so they're loaded eagerly.

To add your own lazy-loaded shortcuts: add a `*.zsh` file to `lib/` and register its command names in the `DIGIVICE_MODULE_CMDS` map in `digivice.plugin.zsh`.

## Testing

Tests use a minimal pure-zsh harness in `tests/` — no external frameworks required (just `zsh` itself). Each test runs the plugin in a fresh `zsh -c` subshell for isolation.

```sh
zsh tests/run.zsh
```

Add new test cases as `test_*` functions in `tests/digivice.test.zsh` (or a new `tests/*.test.zsh` file — the runner picks them up automatically).

## What's included

### Navigation
- `..`, `...`, `....` — go up 1/2/3 directories
- `-` — go to previous directory

### Git
- `gs`, `ga`, `gaa`, `gc`, `gcm`, `gco`, `gcb`, `gb`, `gp`, `gpl`, `gl`, `gd`, `gds`, `gst`, `gstp`
- `gmain` — checkout the repo's default branch (`main` or `master`)

### Node / package managers
- `ni`, `nr`, `nrs`, `nrb`, `nrt` (npm)
- `yi`, `yr` (yarn)
- `pni`, `pnr` (pnpm)
- `drun [script]` — runs a package.json script with whichever package manager the project uses (defaults to `dev`)

### Docker
- `dps`, `dpsa`, `dimg`, `dlog`, `dprune`
- `dsh <container>` — exec a shell into a running container

### Branch status
Automatically prints a one-line warning to the terminal when `cd`-ing into a git repo whose current branch is out of date (checked once per repo per shell, not on every `cd` within it). The check itself is instant — it only compares against already-known remote-tracking info (same as `git status`), never fetching on its own. Two independent things are checked:

- **vs. its own upstream** (`@{upstream}`) — behind, ahead, or diverged, e.g. `⚠️  'main' is behind 'origin/main' by 3 commit(s) - run gpl to update`
- **vs. the repo's base branch** (`origin/main`/`origin/master`) — flags a feature branch that needs a rebase even if it has no upstream of its own, e.g. `🔀 'my-feature' is 5 commit(s) behind 'origin/main' - consider rebasing onto main`

Auto-fetching is **opt-in**: the first time a repo is found to be out of date and no preference has been recorded, you're asked (only in an interactive terminal) whether digivice should keep that repo's remote-tracking info fresh automatically from then on. Your answer is remembered per-repo in `.git/digivice_autofetch`. If enabled, repo entry kicks off a non-blocking `git fetch --all` in the background, throttled to once per repo per `DIGIVICE_FETCH_THROTTLE_SECONDS` (default 300 = 5 minutes; set this variable before the plugin loads to change it). If declined (or never asked, e.g. in a script), nothing is fetched automatically and you keep using `gpl`/`gp` manually.
