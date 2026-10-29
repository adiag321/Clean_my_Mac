# MacCleanUp (`maccleanup`)

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2012%2B-blue?style=flat-square&logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/shell-bash%203.2%2B-green?style=flat-square&logo=gnubash" alt="Bash" />
  <img src="https://img.shields.io/badge/python-3.9%2B-blue?style=flat-square&logo=python" alt="Python" />
  <img src="https://img.shields.io/badge/tests-43%2F43%20passing-brightgreen?style=flat-square" alt="Tests" />
  <img src="https://img.shields.io/badge/license-MIT-purple?style=flat-square" alt="License" />
</p>

An all-in-one macOS system maintenance, disk optimization, and deep cleaning CLI toolkit — zero dependencies, fully scriptable, and safe by default.

MacCleanUp combines deep cleanup of system/app/browser/dev-tool caches with an interactive terminal UI, live hardware monitoring with a health score, a visual disk explorer, universal binary slimming, and a smart app uninstaller — all in native bash and Python, no third-party packages required.

---

## Highlights

- **Interactive TUI Dashboard** — run `maccleanup` with no arguments to open a terminal control panel.
- **Collapsible Category Accordion** — `clean` scans everything up front, then opens a dropdown tree (collapsed by default) where you drill into categories with `←`/`→`, select with `Space`, and only ever delete after an explicit confirmation prompt.
- **Safety first** — `--dry-run` previews every destructive command before touching a byte; an unreadable whitelist file halts execution rather than running unprotected; most uninstalls route through Trash, not `rm -rf`.
- **YAML configuration** — customize target paths, exclusions, and thresholds via `~/.config/maccleanup/config.yaml`.
- **Persistent whitelist** — protect any file or directory from ever being cleaned.
- **Live system monitor with health score** — CPU, RAM, disk, battery, thermal pressure, zombie processes, and a 0–100 composite health score, with `--json`/`--watch` for scripting.
- **Interactive disk explorer** — navigate your file tree in the terminal, surfacing large files above a configurable threshold.
- **Universal binary slimmer** — strip unused Intel `x86_64` slices on Apple Silicon via `lipo` to reclaim gigabytes.
- **Smart app uninstaller** — discovers bundle IDs, finds leftovers across `~/Library`, keeps personal data by default (`--with-data` to remove it too), and lists installed apps as JSON (`--list`).
- **Deep package-manager + dev-tool cleanup** — npm, pnpm (real store, not just the legacy cache dir), pip, cargo, gradle, maven, Homebrew, CocoaPods, Carthage, JetBrains IDE caches, Xcode DerivedData/Previews, Steam, Docker, and more.
- **Touch ID for sudo** — toggle Touch ID authentication for Terminal `sudo` commands.
- **Zero third-party dependencies** — native macOS bash and Python standard library only.

---

## Quick Installation

### Option 1: One-line installer
```bash
git clone https://github.com/adiag321/maccleanup.git ~/.maccleanup
bash ~/.maccleanup/install.sh
```

### Option 2: Clone and install locally
```bash
git clone https://github.com/adiag321/maccleanup.git
cd maccleanup
bash install.sh
```

The installer links `maccleanup` into `~/.local/bin/` and adds it to your shell `PATH`.

---

## Usage

### 1. Launch the interactive dashboard

```bash
maccleanup
```

```text
╔══════════════════════════════════════════════════════════════════╗
║                        MacCleanUp                                ║
║          macOS System Maintenance & Deep Clean Utility           ║
╚══════════════════════════════════════════════════════════════════╝

Hardware: Mac17,3 (Apple M5)  OS: macOS 27.0.1
Storage:  370Gi free of 460Gi (4% used)

Select an action:
  [1]  Clean Mac           [c]  Deep cache, log, browser & leftover cleanup
  [2]  Dry-Run Clean       [d]  Preview reclaimable space (safe preview)
  [3]  Optimize System     [o]  DNS flush, icon cache, QuickLook reset, snapshot thinning
  [4]  Analyze Disk Usage  [a]  Interactive visual directory explorer
  [5]  Live System Monitor [s]  CPU, RAM, Disk, Net, battery & health score
  [6]  Uninstall App       [u]  Remove app with full leftover cleanup
  [7]  Dev Artifact Purge  [p]  Clean stale node_modules, target, .build
  [8]  Installer Cleanup   [i]  Remove old .dmg, .pkg, .iso files
  [9]  Slim Universal Apps [m]  Remove Intel slices on Apple Silicon
  [10] Touch ID for Sudo   [t]  Check / toggle Touch ID authentication
  [11] Operation History   [h]  View log of past actions
  [12] Whitelist Manager   [w]  View & manage protected paths
  [13] Configuration       [k]  View or edit config.yaml
  [14] Install to PATH     [n]  Enable running 'maccleanup' anywhere in terminal
  [0]  Exit [q]

Enter choice [1-14 or key]:
```

---

### 2. Clean Mac (interactive accordion)

Choosing **[1] Clean Mac** scans your system, then opens a collapsed accordion:

```text
  ▶ [1] ● User Essentials ·········································· ~38 MB  (6 items)
  ▶ [2] ● Apple System Services ··································· ~12 MB  (11 items)
  ▶ [3] ● AI & IDE Apps ············································ ~180 MB  (24 items)
  ▶ [4] ● Productivity Apps ········································ ~5 MB  (8 items)
  ▶ [5] ● Browsers ················································· ~170 MB  (13 items)
```

Pressing `→`/`l` on a category opens it to show individual items with their sizes; `←`/`h` closes it again. Nothing is ever deleted without a final confirmation prompt showing the exact item count and total size.

**Controls:**

| Key | Action |
|---|---|
| `↑`/`↓` or `j`/`k` | Move cursor |
| `→`/`l` | Open the category under the cursor |
| `←`/`h` | Close it (or close the parent if you're on an item) |
| `Space` | Toggle selection |
| `e` / `x` | Expand / collapse all |
| `a` | Select / deselect all |
| `c` | Clean selected — asks "Clean N items (~X MB)?" before deleting anything |
| `q` | Quit without changes |

---

## Direct CLI Command Reference

Everything is scriptable without the interactive menu:

| Command | Description | Example |
|---|---|---|
| `maccleanup clean` | Deep cache, log, browser, and package cleanup | `maccleanup clean --dry-run` |
| `maccleanup uninstall <App>` | Smart app uninstaller with leftover cleanup | `maccleanup uninstall "Slack"` |
| `maccleanup uninstall --list` | List installed apps as JSON | `maccleanup uninstall --list` |
| `maccleanup optimize` | DNS flush, QuickLook reset, icon cache rebuild, snapshot thinning | `maccleanup optimize` |
| `maccleanup analyze [path]` | Interactive terminal disk usage explorer | `maccleanup analyze ~/Downloads` |
| `maccleanup status` | Live system monitor with health score | `maccleanup status --json` |
| `maccleanup purge` | Clean stale developer build artifacts | `maccleanup purge --days 14` |
| `maccleanup installer` | Find and clean old `.dmg`, `.pkg`, `.iso` files | `maccleanup installer --days 7` |
| `maccleanup slim` | Remove Intel slices on Apple Silicon Macs | `maccleanup slim --dry-run` |
| `maccleanup touchid` | Check or toggle Touch ID for sudo authentication | `maccleanup touchid status` |
| `maccleanup history` | View audit log of past cleanup operations | `maccleanup history --json` |
| `maccleanup whitelist` | Manage protected paths | `maccleanup whitelist list` |
| `maccleanup config` | View or edit YAML configuration | `maccleanup config show` |
| `maccleanup completion` | Generate shell tab-completion script | `maccleanup completion zsh` |

### Scripting the live monitor

```bash
maccleanup status --json                  # one-shot snapshot
maccleanup status --watch --interval 2     # stream NDJSON every 2s
```

```json
{"timestamp":"2026-10-29T02:51:18Z","health_score":92,"cpu":{"usage_pct":17.4,"idle_pct":83.3},"memory":{"used_mb":845,"total_mb":16384},"disk":{"used_pct":4},"battery":{"state":"AC","pct":85},"thermal_level":"normal","zombie_count":0,"zombie_parents":[]}
```

---

## How it works

MacCleanUp is a single executable plus a library of sourced bash modules — no code is duplicated between the repo and your `PATH`:

```text
~/.local/bin/maccleanup  ──(symlink)──>  /path/to/maccleanup/maccleanup
                                                    │
                                          /path/to/maccleanup/
                                          ├── maccleanup           <- single executable
                                          ├── lib/                 <- feature & core modules
                                          ├── config/defaults.yaml <- shipped template
                                          └── tests/                <- test suite
```

- **Zero duplication, instant updates** — `~/.local/bin/maccleanup` is a lightweight symlink; any edit or `git pull` in the repo takes effect immediately.
- **User state isolation** — personal config and logs live in standard macOS locations:
  - Configuration: `~/.config/maccleanup/config.yaml`
  - Whitelist: `~/.config/maccleanup/whitelist`
  - Operations log: `~/Library/Logs/maccleanup/operations.log`

---

## Configuration (`~/.config/maccleanup/config.yaml`)

```yaml
version: "1"

general:
  dry_run: false
  trash_route: true

clean:
  extra_paths:
    # Mode 1: empty directory contents, keep the folder
    - path: ~/Library/Caches/com.myapp.cache
      mode: clean

    # Mode 2: remove the path entirely
    - path: ~/Library/Application Support/MyApp/tmp
      mode: remove

    # Mode 3: clean only if the directory exceeds a size threshold
    - path: ~/Library/Group Containers/group.myapp/Media
      mode: clean_if_large
      min_size_mb: 500

  # Paths to NEVER touch
  whitelist:
    - ~/Library/Caches/com.apple.Safari

  # Set true to clean ONLY extra_paths and skip built-in paths
  override: false

purge:
  paths:
    - ~/Documents
    - ~/Downloads
    - ~/Desktop
    - ~/Developer
    - ~/Projects
  min_age_days: 14
```

---

## Safety model

- Every destructive command supports `--dry-run`.
- Deleting a whitelist entry that exists but can't be read **halts the run** rather than proceeding unprotected.
- `uninstall` keeps personal data (Application Support, Containers) by default — pass `--with-data` to also remove it.
- `clean`/`purge`/`installer` delete permanently; `uninstall`/`analyze`/`slim` route to Trash.
- Every operation is logged to `~/Library/Logs/maccleanup/operations.log` (`maccleanup history` to review, `MCU_NO_OPLOG=1` to disable).

---

## Automated test suite

```bash
bash tests/test_maccleanup.sh
```

Runs 43 automated assertions covering shell syntax across every module, core CLI flags, whitelist management (including the unreadable-file safety halt), config commands, dry-run safety, Touch ID status, shell completion generation, the status monitor (including `--json`), and uninstall's JSON listing.

---

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for code style, testing requirements, and the PR process.

---

## License

MIT © 2026 Aditya Agarwal. See [LICENSE](LICENSE).
