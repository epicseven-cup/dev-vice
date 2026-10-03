# digivice

An [Oh My Zsh](https://ohmyz.sh/) plugin with general dev productivity aliases and functions: git, npm/yarn/pnpm, docker, and navigation shortcuts.

## Installation

Requires [Oh My Zsh](https://ohmyz.sh/). If you don't have it yet:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

This installs OMZ into `~/.oh-my-zsh` and writes a `~/.zshrc` with a `source $ZSH/oh-my-zsh.sh` line — that's what actually loads plugins, so everything below assumes it's already there.

Clone this repo into your Oh My Zsh custom plugins directory. OMZ auto-loads any file under `$ZSH_CUSTOM/plugins/<name>/` named `<name>.plugin.zsh` (default `$ZSH_CUSTOM`: `~/.oh-my-zsh/custom`), which is exactly what `digivice.plugin.zsh` is:

```sh
git clone https://github.com/epicseven-cup/digivice.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/digivice"
```

Then find the `plugins=(...)` line OMZ's installer already put in `~/.zshrc`, and add `digivice` to it:

```sh
plugins=(git digivice)
```

(Optional) To see the branch-status icon (⬇/⬆/⬍/⟲, see [Branch status](#branch-status-prompt-indicator) below) in your prompt, add this line *after* `source $ZSH/oh-my-zsh.sh` in `~/.zshrc`:

```sh
PROMPT="${PROMPT}"'$(digivice_prompt_info) '
```

Everything else (aliases, tab completion, autofetch) works without this step — it only controls whether the icon is visible.

Reload your shell:

```sh
source ~/.zshrc
```

### Updating

Once installed, just run:

```sh
digivice-update
```

This pulls the latest changes (fast-forward only) into the plugin's own clone, then restart your shell (`exec zsh`) to pick them up. You don't have to remember to do this yourself, either — see [Self-update suggestion](#self-update-suggestion) below.

## Structure

```
digivice.plugin.zsh   # entry point, sources everything in lib/
lib/
  navigation.zsh      # cd shortcuts
  branch_status.zsh    # digivice_prompt_info + autofetch (chpwd hook)
  completions.zsh      # tab completion for gcm/gcb/git (compdef)
  self_update.zsh      # digivice-update + startup self-update suggestion
  git.zsh              # git aliases + gmain + gcanrebase + gcm shorthand + git wrapper
  node.zsh             # npm/yarn/pnpm aliases + drun
  docker.zsh           # docker aliases + dsh
  github.zsh           # GitHub Actions workflow scaffolding
```

Commands are lazy-loaded: `git.zsh`, `node.zsh`, and `docker.zsh` are not sourced at shell startup. Instead each command they provide (`gs`, `drun`, `dsh`, etc.) is registered as a lightweight stub. The first time you actually run one, its module is sourced (defining every real function in that module) and the call is passed through — later calls hit the real function directly, with no extra `source` cost. `navigation.zsh`, `branch_status.zsh`, `completions.zsh`, and `self_update.zsh` need to run unconditionally at shell startup (hooks/completion registration, and the one-time update check), so they're loaded eagerly.

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
- `gs`, `ga`, `gaa`, `gc`, `gco`, `gb`, `gp`, `gpl`, `gl`, `gd`, `gds`, `gst`, `gstp`
- `gmain` — checkout the repo's default branch (`main` or `master`)
- `gcanrebase [ref]` — check whether the current branch could be rebased onto `ref` (defaults to the repo's base branch, e.g. `origin/main`) without hitting conflicts. Actually performs the rebase to find out, but inside a disposable detached worktree, so your real working tree, index, and uncommitted changes are never touched — it's discarded either way. Exits 0 if clean, 1 if it would conflict.

#### Conventional Commits ([conventionalcommits.org](https://www.conventionalcommits.org/))

`gcm <message>` (and **plain `git commit -m`/`-am`/`--message=`**, since digivice wraps `git` itself) auto-expand a leading shorthand commit type:

- Tab-complete it: `gcm <TAB>` **or** plain `git commit -m "<TAB>` (also `-am`, `--message`) suggests `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` with descriptions, colored cyan with a green header (needs a completion system — Oh My Zsh's is on by default). Keep typing to narrow the list, e.g. `"f<TAB>` → just `feat`/`fix`.
- Or type the shorthand directly — it expands either way: `gcm 'ft: add x'` → commits as `feat: add x`. Shorthands: `ft`→feat, `fx`→fix, `dc`→docs, `sty`→style, `rf`→refactor, `pf`→perf, `ts`→test, `bd`→build, `ch`→chore, `rv`→revert. Scope and the breaking-change `!` are preserved: `gcm 'fx(core)!: fix x'` → `fix(core)!: fix x`.
- A message already using a full type, or not matching any recognized type, passes through unchanged. Every other git subcommand is completely unaffected by the `git` wrapper — it only touches `commit`'s message argument.

#### Branch naming

`gcb <name>` (and **plain `git checkout -b <name>`** / `git switch -c <name>`) tab-complete a branch-prefix convention:

| Prefix | Shorthand | For |
|---|---|---|
| `feature/` | `feat/` | A new feature or requirement |
| `bugfix/` | `fix/` | A routine bug fix tied to a dev cycle |
| `hotfix/` | — | A critical patch bypassing the normal release schedule |
| `chore/` | `refactor/` | Tech debt, dependency updates, config changes, cleanups |
| `docs/` | — | Documentation, readmes, wikis |

e.g. `gcb <TAB>` or `git checkout -b <TAB>` lists these (cyan, green header); pick one and keep typing the rest of the branch name.

### Node / package managers
- `ni`, `nr`, `nrs`, `nrb`, `nrt` (npm)
- `yi`, `yr` (yarn)
- `pni`, `pnr` (pnpm)
- `drun [script]` — runs a package.json script with whichever package manager the project uses (defaults to `dev`)

### Docker
- `dps`, `dpsa`, `dimg`, `dlog`, `dprune`
- `dsh <container>` — exec a shell into a running container

### GitHub Actions
- `ghwfnew [name]` — create `.github/workflows/<name>.yml` (default name: `ci`) from a starter template picked by what's in the project: node (`package.json`), python (`requirements.txt`/`pyproject.toml`), or a generic placeholder otherwise. Refuses to overwrite an existing file.
- `ghwfls` — list workflow files in `.github/workflows`
- `ghwfedit <name>` — open a workflow file in `$EDITOR`

### Branch status (prompt indicator)
Like Oh My Zsh's `git` plugin's `git_prompt_info`, digivice provides `digivice_prompt_info` — a small colored icon you add to your own prompt, not a printed message. Add it to `~/.zshrc` **after** `source $ZSH/oh-my-zsh.sh`:

```sh
setopt PROMPT_SUBST   # Oh My Zsh enables this by default
PROMPT="${PROMPT}"'$(digivice_prompt_info) '
```

(or splice it into `RPROMPT`, or into a custom theme's `PROMPT` definition — anywhere command substitution runs on every render.) It's recomputed fresh every time the prompt draws, using only already-known local git info (same as `git status` — never fetches on its own, so it's instant):

| Icon | Meaning |
|---|---|
| `⬇3` (yellow) | behind its own upstream by 3 commits — `gpl` to update |
| `⬆2` (green) | ahead of its own upstream by 2 commits — `gp` to push |
| `⬍1/2` (red) | diverged from its own upstream (behind 1, ahead 2) |
| `⟲5` (cyan) | behind the repo's base branch (e.g. `origin/main`) by 5 commits, even if this branch has no upstream of its own — run `gcanrebase` to check if rebasing would be clean |

Nothing is shown outside a git repo or when the branch is fully up to date.

Auto-fetching is **opt-in**: the first time a repo is found out of date (on `cd` into it, checked once per repo per shell) and no preference has been recorded, you're asked (only in an interactive terminal) whether digivice should keep that repo's remote-tracking info fresh automatically from then on — since the icons above only reflect whatever's already locally known. Your answer is remembered per-repo in `.git/digivice_autofetch`. If enabled, repo entry kicks off a non-blocking `git fetch --all` in the background, throttled to once per repo per `DIGIVICE_FETCH_THROTTLE_SECONDS` (default 300 = 5 minutes; set this variable before the plugin loads to change it). If declined (or never asked, e.g. in a script), nothing is fetched automatically and you keep using `gpl`/`gp` manually.

### Self-update suggestion

Unlike your own projects, digivice's own clone (wherever you installed it under `$ZSH_CUSTOM/plugins/digivice`) is checked for updates automatically and unconditionally — there's no opt-in prompt, since there's nothing project-sensitive about fetching digivice's own public repo. At shell startup (once, not on every `cd`):

- It compares the plugin's own clone against its origin, using only already-known local info — instant, same as everything else above.
- If behind, it prints a one-line suggestion: `💡 digivice: 2 update(s) available - run 'digivice-update' to get them`.
- It also kicks off a throttled, non-blocking `git fetch` of its own repo (default: once per day — `DIGIVICE_SELF_FETCH_THROTTLE_SECONDS`) so that comparison stays reasonably fresh over time without ever fetching on every single shell start.

Run `digivice-update` to actually pull the changes (fast-forward only), then `exec zsh` to reload with them. To turn the check off entirely, set `DIGIVICE_SELF_UPDATE_CHECK=0` before the plugin loads (e.g. in `~/.zshrc`, before the `plugins=(...)` line takes effect).
