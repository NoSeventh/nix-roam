# AGENTS.md

A **dual-mode Nix flake** that supports two management modes from one source tree:

1. **NixOS mode** — desktop: `nixosConfigurations.nixos`; CLI-only WSL: `nixosConfigurations.wsl` (both x86_64-linux).
2. **Portable CLI mode** — user-level Home Manager only, for non-NixOS Linux / WSL / macOS. `homeConfigurations.x86_64-linux`, `aarch64-linux` and `aarch64-darwin` (standalone outputs are named by system, independent of the username).

This file records the maintained architecture and operating conventions. Keep it and `README.md` aligned with implementation changes; historical plans are not required to work on this repository. The split principle: **README = usage, this file = rules, `docs/` = why & how** — mechanism, rationale and history live in the topic pages ([`docs/roam.md`](docs/roam.md), [`docs/mirrors.md`](docs/mirrors.md), [`docs/bootstrap.md`](docs/bootstrap.md)); keep additions here to rules and pointers rather than growing new walls of text.

Standalone mode supplements the native package manager: keep system services and GUI applications under the native OS, with no root Home Manager profile or `darwinConfigurations`. Select explicit flake outputs; do not use `--impure`, environment variables or the evaluation host to choose a target. Standalone Linux ships explicit per-arch outputs — `x86_64-linux` and `aarch64-linux` — selected by the arch-aware `roam switch` and `bootstrap/bootstrap.sh`, never by the evaluation host. The macOS output is aarch64-darwin only; NixOS outputs remain x86_64-linux.

## Detect the current host before acting

This repository defines both NixOS and standalone Home Manager targets; **the target present in the repo does not identify the environment where an agent is currently running**. Before diagnosing, rebuilding, activating, or editing environment-specific settings, inspect the actual host (at minimum `/etc/os-release`, `uname -a`, and whether `/etc/NIXOS` exists).

- `/etc/NIXOS` exists → current host is NixOS; system fixes belong under `hosts/`, `profiles/`, or `modules/` (desktop-only modules under `modules/desktop/`), and activation uses `nixos-rebuild`.
- `/etc/NIXOS` absent → current host is standalone Nix on Linux/WSL (or macOS); fixes belong under `home/standalone-*`, `home/common.nix`, or `bootstrap/` as appropriate, and activation uses Home Manager.
- WSL with `/etc/NIXOS` is NixOS-WSL and uses `.#wsl`; other WSL distributions use standalone Home Manager.
- Never infer the current host from the working directory, hostname, flake outputs, `/run/current-system` alone, or wording such as “this machine” in older documentation. State the detected environment before choosing a mode-specific fix.

## Build & activate commands

| Target | Command |
|---|---|
| Any, auto-detected | `bash bootstrap/bootstrap.sh` (detects OS / NixOS / arch / sudo and dispatches; sub-scripts remain directly runnable) |
| NixOS desktop | `sudo nixos-rebuild switch --flake .#nixos` |
| NixOS-WSL | `sudo nixos-rebuild switch --flake .#wsl` |
| Fresh NixOS desktop (live ISO) | `bash bootstrap/nixos.sh install` (root in the installer; `/mnt` pre-mounted) |
| Existing NixOS / NixOS-WSL | `sudo bash bootstrap/nixos.sh` (auto-detects adopt; WSL → `.#wsl`) |
| Fresh Linux/WSL (no Nix yet) | `bash bootstrap/linux.sh` (installs Nix + HM, then activates; target defaults by arch) |
| Fresh macOS (no Nix yet) | `bash bootstrap/darwin.sh` (installs Nix + HM, then activates) |
| Existing Nix+HM macOS | `home-manager switch --flake .#aarch64-darwin` |
| Existing Nix+HM Linux/WSL | `home-manager switch --flake .#x86_64-linux` (aarch64 hosts: `.#aarch64-linux`, or just `roam switch`) |
| Remote (no clone) | `home-manager switch --flake "git+https://gitee.com/qihaoxu/nix-roam.git#x86_64-linux"` |

Aliases are plain operational shortcuts defined in **`home/common.nix`** (`programs.bash.shellAliases`): `ll`/`lt`/`la`, `npmr`, `ff`/`ffn`, the IHEP/JUNO `ssh`/`sshfs`/workdir shortcuts, `root`, plus the Linux-only distrobox aliases (gated attrset-level with `lib.optionalAttrs isLinux`). **There are no switch aliases** — `hms` and `nrs` were removed 2026-09-28 once `roam switch` was live-verified on both fronts; `roam` is the single switch/maintenance entry point (`switch`/`status`/`doctor`/`rollback`/`gc`/`check`/`update`/`flake`/`info`, bash completion included).

`roam` is `packages/roam.sh` (macOS-Bash-3.2 compatible), packaged by `packages/roam.nix` as a `symlinkJoin` of a `writeShellApplication` `bin/roam` (build-time `bash -n` + shellcheck gate) plus its completion file, shipped through the shared `cli-dev.nix` list to all four install sites. Switching goes through nh on **both** fronts — `nh os switch --diff always .` on NixOS (WSL prints the stc-exit-4 recovery hint on failure), `nh home switch --diff always --configuration <system> .` on standalone with the arch-named output + `meta.json` user guard (refuses cleanly when the login user differs). Repo-touching subcommands must run from a checkout (the flake argument is the cwd-relative `.`), and directory name = hostname = output attribute is what makes nh's hostname default resolve. No `runtimeInputs` — zero closure additions. nh's generation semantics, drift/rollback behavior, the WSL stc-exit-4 traps, completion lazy-loading and the tests live in [`docs/roam.md`](docs/roam.md).

Update flake dependencies with `nix flake update` (or `roam update` to pick inputs), review and commit `flake.lock`, then build the affected targets; `nix-channel --update` does not update the lock file.

**Evaluation + build CI exists (`.github/workflows/eval.yml`); script-level tests live in `tests/`, wired as flake `checks`.** The workflow evaluates the drvPath of all five outputs on pushes (after Gitee → GitHub sync), daily, and manually, **then builds the standalone Linux x86_64 activation package** (`nix build --no-link`, with a runner disk-cleanup step — the closure incl. C++ ROOT/toolchains is ~6-8GB). Evaluation catches upstream option removals; the build step catches eval-invisible failures — notably HM buildEnv conflicts (gcc+clang, dual `python3.withPackages`), which are exactly the historical breakages in this repo and are all build-time errors. NixOS toplevels stay eval-only (closures too large); aarch64 needs ARM hardware. A final step runs `nix flake check`, which builds the repo's `checks` (both Linux systems): `shellcheck-scripts` — the static gate for scripts outside `writeShellApplication`'s (notably `packages/roam-completion.bash`, `tests/*.sh`, `bootstrap/*.sh` and `.githooks/pre-push`) — and `roam-unit-tests` (`tests/run-all.sh`; the unit tests source `packages/roam.sh` and `.githooks/pre-push` directly, so keep their `${BASH_SOURCE[0]} = $0` dispatch guards intact when editing — mechanics and sandbox findings in [`docs/roam.md`](docs/roam.md)). All three layers are post-hoc; the opt-in pre-push hook (`.githooks/pre-push`, enabled once with `git config core.hooksPath .githooks`) front-runs layer 1 locally — **diff-gated**: a push whose delta touches no eval input is released without evaluation — the closed-form skip list `EVAL_SKIP_RE` in the hook is a **blacklist** (docs/tests/bootstrap/.github/.githooks plus the root README/AGENTS/LICENSE/.gitignore are the known non-inputs, tests being checks-only; everything else, known or unknown, counts as an eval input). Blacklist on purpose: a stale entry only ever costs an extra eval, whereas the former whitelist's omission would wrongly skip. A static audit at the end of `tests/prepush-gate.sh` pins that no `.nix` file references a skip-listed path (the one sanctioned `${./tests}` checks reference excepted) and that no `.nix` lives inside them; otherwise one `roam check nixos wsl x86_64-linux aarch64-linux aarch64-darwin` runs (multi-target since 2026-09-29: evals concurrent, all finish before exit, rc aggregates); bypass once with `git push --no-verify`. Operational notes: [`.github/SYNC.md`](.github/SYNC.md). Build without activation using `nix build --no-link` with the appropriate target:

- Desktop: `.#nixosConfigurations.nixos.config.system.build.toplevel`
- NixOS-WSL: `.#nixosConfigurations.wsl.config.system.build.toplevel`
- Standalone Linux: `.#homeConfigurations.x86_64-linux.activationPackage` (aarch64 output builds on ARM hardware; from x86_64 only `nix eval` works)

`nix run` on an activation package is not a dry build. A successful WSL build on another Linux distribution does not verify WSL boot or login.

## Architecture: one shared CLI list, four install sites

The core pattern. `packages/cli-dev.nix` is a **pure function** returning a cross-platform package list, imported in **four** places. Platform-specific packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` guards inside `cli-dev.nix`:

```
packages/cli-dev.nix         ({ pkgs, pkgs-stable, ... }: [ ... ])  cross-platform (platform-conditional inside)
        ├── profiles/cli.nix              → environment.systemPackages  (NixOS-WSL)
        ├── modules/desktop/core.nix      → environment.systemPackages  (system-level, sudo-visible)
        ├── home/standalone-linux.nix     → home.packages               (user-level, non-NixOS Linux)
        └── home/standalone-darwin.nix    → home.packages               (user-level, macOS)
```

- **NixOS**: CLI tools land in `environment.systemPackages` → `/run/current-system/sw/bin` → inside sudo `secure_path`, so `sudo <tool>` works. This intentionally makes bare CLI tools available to root without a separate root profile.
- **Non-NixOS**: same list → `home.packages` → user profile. Home Manager does not configure sudoers; do not assume `sudo -E` bypasses the native sudo `secure_path`.
- **NixOS-only runtimes**: `profiles/nixos-base.nix` adds stable Node.js/npm, pnpm, R and a single stable Python scientific environment (including PyROOT) to both desktop and WSL. Python and PyROOT use the same Python package set; its wrapper sets the matching `R_HOME` for rpy2. Standalone Linux/Darwin do not explicitly install these runtimes; shared `packages/cli-dev.nix` retains standalone `uv`. The separate C++ ROOT application (`pkgs-stable.root`) remains in the shared Linux-only list for NixOS and standalone Linux, not Darwin. Internal interpreter dependencies of applications/editors are not project runtimes and should not be removed. npm registry/prefix configuration remains shared for natively installed Node.
- `nh` lives in this shared list as `roam switch`'s rebuild frontend on **both** fronts (NixOS → `nh os`, standalone → `nh home`), single-sourced here since 2026-09-28 when the standalone backend migrated from `home-manager switch` — the former NixOS-only `programs.nh.enable` was removed (the module did nothing beyond installing the package).
- When adding a CLI tool, decide: needs a dotfile/HM module → `home/common.nix`; bare CLI binary → `packages/cli-dev.nix`. Don't duplicate between the two.
- Linux-only / Darwin-only packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` inside the main list.

## Home Manager layout (`home/`, not root `home.nix`)

| File | Role |
|---|---|
| `home/common.nix` | Cross-platform **CLI-only** HM core (git, bash, starship, helix, ssh, nixvim, fastfetch, btop dotfile). Imported by both modes. **Zero GUI assumptions.** |
| `home/nixos-cli.nix` | NixOS-WSL HM entry = `common.nix` + user identity. Shared CLI tools installed system-wide by `profiles/cli.nix`; development runtimes by `profiles/nixos-base.nix`. |
| `home/default.nix` | NixOS entry = `common.nix` + GUI terminals (alacritty/ghostty/fuzzel) + GUI dotfiles (kitty/wezterm terminals; niri/hypr compositor configs). |
| `home/standalone-linux.nix` | Non-NixOS Linux entry (both x86_64 and aarch64 use this module) = `common.nix` + `packages/cli-dev.nix`. Zero GUI. Idempotent activation scripts append guarded session-vars loaders to `~/.zshrc` (POSIX source) and fish config (`bass` if present, else PATH-only) — each gated on that shell being actually in use (login shell matches or the rc file already exists); rc files are never taken over and none are created for shells not in use. The module also adds `~/.nix-profile/bin` to `home.sessionPath` (merged with `common.nix`'s list): single-user Nix installs carry their only PATH hook in user dotfiles, which the HM bash login-chain takeover replaces — without this entry a freshly activated single-user machine has no `nix` on PATH (multi-user installs are covered system-side by `/etc/profile.d/nix-daemon.sh`; found on the first full single-user run, ArchLinux-WSL 2026-09-24). |
| `home/standalone-darwin.nix` | macOS entry = `common.nix` + `packages/cli-dev.nix`. Platform-conditional via `stdenv.hostPlatform.isDarwin`. Zero GUI. Keeps zsh native: no `programs.zsh`, never takes over `~/.zshrc`; an idempotent activation script appends a guarded `hm-session-vars.sh` loader so session variables/PATH load in zsh. |
| `home/nixvim.nix`, `home/fastfetch.nix` | Split sub-configs imported by `common.nix`. |

GUI HM config stays in `home/default.nix` only — **never** put GUI modules in `common.nix` (breaks WSL/macOS).

`flake.nix` wires it: `nixosHome` selects `home/default.nix` for the desktop and `home/nixos-cli.nix` for WSL; standalone mode uses `mkStandaloneHome` with platform-specific `standalone-{linux,darwin}.nix`. `home.username`/`homeDirectory`/`stateVersion` are injected by the flake (standalone via `mkStandaloneHome`, NixOS entries via `extraSpecialArgs`); `stateVersion` ("26.05") is itself single-pointed in `flake.nix`'s `let` and threaded to both `home.stateVersion` and `system.stateVersion` via `specialArgs`/`extraSpecialArgs`.

The local username is defined **once** — `username` in the repo-root **`meta.json`** (a data file, not Nix syntax, because the bootstrap scripts must read it *before* Nix exists; `flake.nix` loads it via `builtins.fromJSON (builtins.readFile ./meta.json)`, the scripts via a sed on a format we own) — and passed to every NixOS module and HM entry via `specialArgs`/`extraSpecialArgs`. The same file also single-sources the substituter string (`substituters`, space-separated) and the nix-community cachix key (`nixCommunityCachixKey`): `home/nix-cn.nix` and `modules/fix-network.nix` read them via `fromJSON`, the bootstrap scripts via the same sed pattern. `users.users.*`, `home-manager.users.*` and the `roam switch`/bootstrap user guards all derive from it, so adopting a different login name is a one-line edit of `meta.json`; standalone outputs are named by system (`x86_64-linux` / `aarch64-linux` / `aarch64-darwin`) and don't move with it. **No script falls back to a hardcoded username or cache list** — extraction failure aborts with an error (a silent fallback would quietly configure the wrong user after a reformat, or write an empty substituter line into nix.conf). Remote identities (IHEP/JUNO accounts, git email) in `home/common.nix` are personal remote accounts and deliberately do **not** derive from it.

## Directory structure

```
flake.nix                  # Explicit host/home outputs; pkgsFor instantiates unstable + stable per system (shared nixpkgsConfig)
meta.json                  # Single-point local username + cache metadata (substituters string, cachix key); read by flake-side modules AND bootstrap scripts before Nix exists — data file, not Nix
profiles/                  # Explicit shared profiles: nixos-base, desktop, desktop-lite, locale, CLI; hardware/ = dormant GPU/VM profiles
hosts/wsl/                 # NixOS-WSL entry, no physical hardware config
hosts/nixos/               # Current machine entry (host-specific settings) + tracked hardware-configuration.nix + variables.nix knobs
hosts/_template/           # New-host template (default/variables/hardware stub) — bootstrap scaffolds hosts/<hostname>/ from it
modules/                   # Shared NixOS modules (fix-network); modules/desktop/ = desktop-host-only modules
home/                      # Home Manager config (NixOS + standalone)
packages/cli-dev.nix       # Shared CLI tool list (pure function) — see architecture above
packages/roam.{nix,sh}     # roam unified CLI (switch/status/doctor/rollback/gc/check/update/flake/info) — symlinkJoin of the writeShellApplication bin/roam + script + bash-completion file (roam-completion.bash), shipped via the shared cli-dev list
tests/                     # Script-level tests: sourced roam.sh + pre-push diff-gate unit tests (fixtures/) + completion harness + scaffold-block & old-name-reference gates → flake `checks`, run by CI via `nix flake check`
.githooks/                 # pre-push hook: diff-gated five-output eval gate via multi-target roam check (opt-in, core.hooksPath)
bootstrap/bootstrap.sh       # Unified auto-detecting entry (OS / NixOS / arch / sudo) dispatching to the scripts below
bootstrap/linux.sh         # Seven-step installer for standalone Linux/WSL (multi-user or single-user Nix install)
bootstrap/darwin.sh        # macOS counterpart (Apple Silicon only)
bootstrap/nixos.sh         # NixOS bootstrap: install (live ISO) / adopt (running system or NixOS-WSL)
dotfiles/                  # Raw config files, referenced via ../dotfiles from home/ and modules/
docs/                      # Mechanism & history pages split out of this file: roam.md (switching system), mirrors.md (China caches), bootstrap.md (install chains), VALIDATION.md (dated verification records)
AGENTS.md                  # Maintained architecture and operating conventions
.github/workflows/         # Gitee → GitHub synchronization + flake output evaluation/build CI (eval.yml)
.github/SYNC.md            # Synchronization operation and limitations
```

## Host layout

`hosts/nixos/default.nix` is the current machine entry: it imports `profiles/desktop.nix` and its tracked `hardware-configuration.nix`, and holds only machine-specific settings (boot/loader, kernel, `networking.hostName`, power/lid policy, user groups, sshd). There is no root `configuration.nix`. Keep generated hardware files under `hosts/<hostname>/` and track them so Git Flake evaluation remains pure and reproducible; the root `/hardware-configuration.nix` path is ignored only to prevent accidental regeneration in the wrong location.

Each NixOS host also carries a **`hosts/<hostname>/variables.nix`** knob file (a plain attrset). `flake.nix` loads it and passes it as the `vars` specialArg — the only wiring point; modules that need per-host variation declare `vars` in their function header (see `profiles/nixos-base.nix`'s `time.timeZone` and the optional `gpuBusIDs` consumed by `profiles/hardware/nvidia.nix`) instead of importing `hosts/${host}/...` by string path. A module requiring `vars` that isn't reached through a `nixosConfigurations` block passing it fails at evaluation (fail-loud). Standalone Home Manager entries deliberately receive no `vars` — no consumer exists and unguarded references would break standalone evaluation.

**Dormant hardware profiles live in `profiles/hardware/`** (`nvidia.nix`, `amd.nix`, `intel.nix`, `vm-guest.nix`) for future machines with different GPUs or VM guests. Following the explicit-import rule, they are inert until a host's `default.nix` imports one (choose per machine; `hosts/nixos` stays on the default mesa stack and imports none). `nvidia.nix` reads the optional `vars.gpuBusIDs` knobs — without them it is a plain dGPU config, with `nvidia+intel`/`nvidia+amdgpu` it enables prime offload. They are not in any output's module list, so CI evaluation does not cover them; they were eval-verified via `extendModules` overlays (2026-09-19, see VALIDATION.md) but never on real hardware — validate on the first machine that imports one.

**Adding a new machine:**

Fast path: run `sudo bash bootstrap/nixos.sh adopt --target <hostname>` on the machine itself (or `install --target <hostname>` from the live ISO). When `hosts/<hostname>/` is missing, the script scaffolds it from `hosts/_template/` (replacing the `__HOSTNAME__` placeholder), prints paste-ready desktop/CLI `flake.nix` output blocks, and waits for the manual paste — it never edits `flake.nix` itself. The equivalent manual steps:

1. Copy `hosts/_template/` to `hosts/<hostname>/` and replace `__HOSTNAME__`. The convention is directory name = `networking.hostName` = output attribute name (so `roam switch`/`nh` auto-match by hostname). Keep `profiles/desktop.nix` for a full desktop, `profiles/desktop-lite.nix` for the decided light composition (core + dev + office + flatpak + browsers + agents; no media/proxy/gaming/virtualization/mnt/fallback DEs), compose `nixos-base.nix` + selected `modules/desktop/` tiers for anything in between, or `nixos-base.nix` + `cli.nix` for CLI-only; import one `profiles/hardware/*.nix` GPU/VM profile if the machine needs it.
2. Fill `variables.nix` knobs (`timeZone`, optional `gpuBusIDs`) and provide a real `hardware-configuration.nix` — the install chain regenerates it, adopting an existing system means copying that machine's current file in.
3. Add the `nixosConfigurations.<hostname>` output in `flake.nix` pointing at `./hosts/<hostname>` (copy the desktop or WSL block as appropriate; the scaffold prints both variants) — and keep `(hostnameGuard "<hostname>")` in the modules list (the scaffold-printed blocks carry it): the dir = hostName = output-attr convention is asserted at build time and preflighted by `roam switch` before dispatching to nh.
4. If the host needs a different HM user profile, pass a different module to `nixosHome`.
5. Build without activating via `nix build --no-link .#nixosConfigurations.<hostname>.config.system.build.toplevel` before the first `switch`; preserve that host's original `system.stateVersion` when adopting an existing system.

## Module loading: explicit imports everywhere

Both NixOS hosts import their modules explicitly through profiles — `flake.nix` does **not** scan `modules/` (no auto-loading). `modules/fix-network.nix` is shared (imported via `profiles/nixos-base.nix`); everything under `modules/desktop/` is desktop-host-only and imported explicitly by `profiles/desktop.nix`. Adding a module file changes nothing until it is added to the importing profile's list; likewise removing/renaming requires updating that list.

Module function signatures vary. For new edits, declare the parameters you use and retain `...`; some existing headers contain unused parameters. Referenced package sets must be in scope and supplied via module arguments. `modules/fix-network.nix` currently uses `{ ... }:` and only declares settings/imports.

Match the channel to the param you reference: `pkgs-stable` for stable, `pkgs` (unstable) for everything else. There is no `pkgs-master` — the master channel was removed on 2026-09-16 (it had no consumers); reintroduce it in `flake.nix` (`inputs` + `pkgsFor` + `specialArgs`) if ever needed.

Key modules (under `modules/desktop/` unless noted) — app tiers split 2026-09-26 out of the former giant `programs.nix` + `services.nix` + `flatpak-linyaps.nix` (pure reorganization: the 635-path `environment.systemPackages` set verified identical before/after; only list concat order changed, so the desktop drvPath moved while WSL/standalone stayed byte-identical):
- `core.nix` — **open-source-only** desktop base: firefox/chromium (+ `programs.*` wrappers), kitty, shells, monitoring, screenshots, compression, syncthing/localsend, `nix-ld`, earlyoom (the rustdesk-server stub lives here), and the trailing `++ (import ../../packages/cli-dev.nix {...})`. Proprietary software never lands here — a lite host imports just this tier for a usable clean desktop.
- `browsers.nix` — proprietary/experimental browsers (google-chrome, microsoft-edge, servo), kept out of core by the open-source rule.
- `dev.nix` — editors (vscode/zed/warp/nvim/neovide/helix/vim/emacs), clang toolchain, rstudio, biome, gitui, distrobox/bubblewrap, and the `services.mysql` dev service.
- `media.nix` — audio players, image/video editors, CAD suite, obs, qbittorrent, bilibili clients.
- `office.nix` — office suites, thunderbird/calibre/zotero, siyuan, calendar/translator, CN apps (qq/wemeet/qqmusic/wordbook), zoom/mattermost, texlive scheme-full (moved here from `dev.nix` in d8d1ec3; the lite profile imports this tier, so lite carries TeX too) + the **wechat overlay** (must travel with the CN apps; not importing this tier disables the overlay cleanly).
- `proxy.nix` — clash stack (mihomo/clash-verge-rev/clash-nyanpasu), sing-box/v2rayn/proxypin + `programs.clash-verge` (tun/service mode).
- `gaming.nix` — `programs.steam` + `hardware.graphics.enable32Bit` (32-bit GL lives with its consumers; `virtualization.nix` keeps its own same-value declaration for wine).
- `flatpak.nix` / `desktop-managers.nix` — split from the former flatpak-linyaps.nix: app stores + SJTU flatpak mirror vs GNOME/Plasma6 fallback DEs (GNOME extensions, KDE apps, mutter dconf features).
- `session.nix` — shared session stack (GDM + niri default session, PipeWire, printing, graphics, ssh askpass), split 2026-09-26 from profiles/desktop.nix so the full and lite desktop profiles compose it identically.
- `niri.nix` — Niri (primary) + Hyprland + Sway fallbacks; `dms-shell` enabled as the shell.
- `agents.nix` — `hermes-agent` service + AI tools (cursor, claude-code, codex, opencode…). See "Secrets" below.
- `mnt.nix` — IHEP juno sshfs user service (work-machine specific; the system-side counterpart of the IHEP identity in `home/common.nix`).
- `virtualization.nix` — Docker is the container engine (podman commented out; enable one or the other, never both), plus libvirtd/waydroid/wine.

## Two managed nixpkgs channels (plus nixvim's own)

- `nixpkgs` (unstable) → `pkgs`
- `nixpkgs-stable` (nixos-26.05) → `pkgs-stable`

`pkgsFor system` instantiates **both** channels under one shared `nixpkgsConfig` (`allowUnfree`, shared `permittedInsecurePackages`); `mkStandaloneHome` uses its `.unstable`/`.stable`, NixOS hosts receive `.stable` via `specialArgs`/`extraSpecialArgs` and provide their own unstable `pkgs` through `nixosSystem`. Standalone Linux per-arch outputs are explicit (`x86_64-linux` / `aarch64-linux`, named by system like the darwin one) — there is no `forAllSystems` auto-expansion helper; adding a system means adding an explicit output.

A **third nixpkgs instance** exists implicitly: `nixvim` does *not* `follows` nixpkgs (its `nixos-26.05` branch expects the matching nixpkgs) and brings its own in `flake.lock`. Its plugin closure therefore tracks nixvim's lock entry, not the repo's unstable/stable — don't expect `nix flake update` bumps of nixpkgs to move nixvim plugins.

Convention: heavy/stability-sensitive packages (editors, office, toolchains) on `pkgs-stable.`; bleeding-edge stuff on `pkgs`.

```nix
environment.systemPackages = with pkgs; [
  vscode                 # unstable
  pkgs-stable.libreoffice
  pkgs-stable.neovim
];
```

## Flake inputs (actual)

Active: `nixos-wsl`, `home-manager` (master), `nixvim` (nixos-26.05), `hermes-agent`. The former `chaotic` input was removed on 2026-09-06; the shell stack it used to provide (`dms-shell`, `noctalia-shell`, `quickshell`, `dsearch`, and the `programs.dms-shell` NixOS module) now comes from nixpkgs unstable directly.

**The `noctalia`, `dms`, `quickshell`, `zen-browser` inputs are commented out in `flake.nix` and must stay that way** — they are obsolete. `modules/desktop/niri.nix` references the *packages* `noctalia-shell`, `dms-shell`, `quickshell`, `dsearch` and the `programs.dms-shell` option; all of these come from nixpkgs unstable (formerly via `chaotic`, which has been removed). Don't reference `inputs.noctalia`/`inputs.dms`/`inputs.quickshell` — they don't exist.

Access flake packages in modules that declare `inputs`:
```nix
inputs.nixvim.homeModules.nixvim   # used in home/common.nix
```

## China mirrors (CERNET / MirrorZ)

Standing rules — mechanism, key placement rationale and the rainbow-delimiters incident that added the community cache live in [`docs/mirrors.md`](docs/mirrors.md):

- **Single source of truth** for the substituter list *and* the cachix key is the repo-root `meta.json`; `home/nix-cn.nix` consumes it Nix-side, the three bootstrap scripts via the same sed pattern they use for `username`. Current list: NJU → TUNA → USTC → SJTU → `cache.nixos.org` → `nix-community.cachix.org` last. Don't reintroduce hardcoded lists or silent fallbacks.
- Never configure Nix to use `help.mirrors.cernet.edu.cn` / `mirrors.cernet.edu.cn` as a source — it's an index/help aggregator, not a mirror.
- The cachix key belongs **only where it is honored**: `modules/fix-network.nix` and the bootstrap scripts (daemon-side `nix.custom.conf` / single-user `nix.conf`, `extra-` prefixed). It must **not** go in `home/nix-cn.nix` — `trusted-public-keys` is a restricted setting for non-trusted users and the daemon ignores it with a warning.
- **Keep `bootstrap/linux.sh` and `bootstrap/darwin.sh` write mechanics mirrored** (multi-user: `trusted-substituters` + `extra-trusted-public-keys` in `/etc/nix/nix.custom.conf`, included from `/etc/nix/nix.conf`; single-user: user-level `nix.conf`) — otherwise Nix ignores user-level substituters.
- Binary caches only cover store paths; flake inputs still fetch from GitHub — don't point flake inputs at the dead USTC/SJTU git mirrors. SJTU is the only listed mirror with a nix-darwin binary cache.

## Secrets

`modules/desktop/agents.nix` enables `services.hermes-agent` with `environmentFiles = [ "/etc/hermes/env" ];`. That file holds API keys (DeepSeek etc.) and is **not** in the repo — it must exist on the target machine or the service won't start with valid creds. `systemd.tmpfiles.rules` creates `/etc/hermes` (0750 root:hermes); `xuqihao` is added to the `hermes` group for shared-state access.

## Handling EOL / insecure packages

Inspect **both** `flake.nix` and `profiles/nixos-base.nix` when an insecure-package evaluation error occurs. Each nixpkgs instance has a separate allowlist; an exception on system unstable does not cover `pkgs-stable` or standalone unstable.

Current source values (not a claim that every target builds):

| nixpkgs instance | Location | `permittedInsecurePackages` |
|---|---|---|
| Stable **and** standalone unstable (shared) | `flake.nix` → `nixpkgsConfig` (consumed by `pkgsFor` for both channels) | `electron-41.9.1` (added 2026-09-26: the desktop closure references it through this config's instance, probe-verified — removal breaks desktop eval; standalone doesn't reference it, allow-only semantics leave its drvPath unchanged) |
| NixOS unstable, desktop/WSL | `profiles/nixos-base.nix` | `electron-40.10.5`, `pnpm-10.29.2` |

These lists deliberately differ (per-instance needs). Add an approved exact package/version exception to every affected instance in both files as needed; do not assume one edit covers every output or expand permissions just to make documentation match. Validate the affected package/target after changing exceptions.

`pnpm-10.29.2` on system unstable is referenced only by the desktop closure (GNOME module chain via `services.desktopManager.gnome`); the WSL toplevel derivation is byte-identical without it (verified 2026-09-14). It must still be declared in the shared `profiles/nixos-base.nix`: `nixpkgs.config` merges shallowly across modules, so a second `permittedInsecurePackages` list in `profiles/desktop.nix` would shadow the `electron-40.10.5` entry instead of extending it.

## buildEnv conflict gotchas

Hard-won — read the header comments in `packages/cli-dev.nix` before editing that file. The managed Python environment now lives only in `profiles/nixos-base.nix`; do not reintroduce it into standalone Home Manager:
- **Never put both `gcc` and `clang` in a Home Manager `home.packages`**: both wrappers provide `bin/ld` → buildEnv conflict → build fails. On NixOS system-level (`environment.systemPackages`) they coexist fine; in user-level HM they don't. Need clang on a non-NixOS box → use the native package manager.
- **Never put bare `python3` alongside `python3.withPackages (...)`**: buildEnv conflict. Use only the `withPackages` form.
- **Never have two separate `python3.withPackages (...)` calls in the same HM `home.packages`**: both produce python3-env derivations that collide on `bin/idle3` etc. in HM's buildEnv. Merge all Python packages into a single `withPackages` call, using `stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` guards for platform-specific packages.

## Style

- **2-space** indentation, no formatter configured — maintain by hand.
- Function headers use ellipsis: `{ config, pkgs, pkgs-stable, ... }:` (only list what you use).
- Numbered section dividers: `# --- 1. Section ---`.
- `with pkgs; [ ... ]` for package lists; prefix stable/master explicitly.
- Mixed English/Chinese comments are normal. Prefer commenting-out over deleting.
- No trailing comma on the last attribute.

## Quick rules

- Track `hosts/<hostname>/hardware-configuration.nix` for reproducible Git Flake builds; only the accidental root path `/hardware-configuration.nix` is ignored.
- Modules are imported explicitly: desktop-host-only modules go in `modules/desktop/` **and** must be added to `profiles/desktop.nix`'s import list; shared NixOS modules go in `modules/` and are imported by the relevant profile.
- GPU/VM differences are handled by `profiles/hardware/*.nix` dormant profiles imported per host (not by GPU-named flake outputs); hybrid-graphics BusIDs go in that host's `variables.nix` as `gpuBusIDs`.
- GUI HM modules → `home/default.nix` only; CLI → `home/common.nix` (needs config) or `packages/cli-dev.nix` (bare tool); Linux-only/Darwin-only packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` inside `cli-dev.nix`.
- Don't uncomment the `noctalia`/`dms`/`quickshell` inputs — those packages now come from nixpkgs unstable (`chaotic` removed).
- The local username and the Nix cache list/key live in one place: the repo-root `meta.json` (`username`, `substituters`, `nixCommunityCachixKey`), read by `flake.nix`/`home/nix-cn.nix`/`modules/fix-network.nix` (fromJSON) and every bootstrap script (sed on a format we own, fail-loud). Everything else (`users.users.*`, `home-manager.users.*`, the `roam switch`/bootstrap user guards, bootstrap password setup) derives from or reads that value; standalone flake outputs are named by system (`x86_64-linux` / `aarch64-linux` / `aarch64-darwin`) and are username-independent — don't reintroduce hardcoded local usernames, cache lists or silent fallbacks. Remote identities (IHEP/JUNO accounts, git email) in `home/common.nix` are separate.
- Adding an EOL exception → inspect **both** `flake.nix` and `profiles/nixos-base.nix` and update the affected nixpkgs instances; their current lists differ.
- Every `nixosConfigurations` output includes `(hostnameGuard "<attr>")` — the hosts/<dir> = `networking.hostName` = output-attr convention is build-asserted and preflighted by `roam switch` on NixOS.

## NixOS-WSL

`hosts/wsl/default.nix` imports `profiles/nixos-base.nix` and `profiles/cli.nix`; the flake supplies NixOS-WSL and integrated Home Manager with `home/nixos-cli.nix`. Software tracks standalone Linux via the same list and common HM configuration. Do not import `home/standalone-linux.nix` into NixOS. Shared system settings belong in `profiles/`; desktop services stay in the desktop module set. NixOS-WSL does not require a generated physical hardware configuration.

`hosts/wsl/default.nix` also masks **both** `getty@tty1.service` and `autovt@tty1.service`, and sets `users.users.<username>.linger = true`. Both are load-bearing for `roam switch` on NixOS: stc exit 4 aborts nh **before** the generation is created, and such switches are ephemeral on NixOS-WSL (lost at the next `wsl --shutdown`); masking one getty template instance does not cover the other, and linger is a WSL-only need (desktop hosts get the user manager from display-manager login — which is why it lives here and not in `profiles/nixos-base.nix`). Full causality and the recovery path in [`docs/roam.md`](docs/roam.md); after any failed switch, recover with `sudo nixos-rebuild switch --flake .#wsl`.

“CLI-only” means shared base tools with standalone Linux, including tools such as mpv and the C++ ROOT application; do not remove packages merely because they can use graphics. Keep one shared CLI list and `home/common.nix`. Node/npm/pnpm and Python/PyROOT/R are an intentional NixOS-only addition through `profiles/nixos-base.nix`, identical on desktop and WSL. WSL uses system-level installation for bare tools and integrated Home Manager for user configuration; do not separately activate standalone Home Manager there.

Default WSL host/user are `wsl` / `xuqihao`. Activate explicitly with `sudo nixos-rebuild switch --flake .#wsl`. A freshly imported distro can be brought under this configuration by running `sudo bash bootstrap/nixos.sh` (auto-detected adopt → `.#wsl`). Nix maintenance automation (weekly GC `--delete-older-than 2w`, daily optimise, weekly user-generation cleanup) comes with `profiles/nixos-base.nix` — sunk there 2026-09-26 from a former desktop-only module — and is active on WSL too. Shared defaults include `system.stateVersion = "26.05"`; preserve an existing target's original stateVersion when adopting this configuration. Desktop sessions, databases, container services, Hermes and remote mounts are not enabled by this entry; add services only when requested. WSLg integration follows NixOS-WSL defaults.

## Nix configuration ownership and bootstrap

- Keep `home/nix-cn.nix` out of `home/common.nix`: NixOS manages daemon settings through `profiles/nixos-base.nix` → `modules/fix-network.nix`, while standalone manages user `~/.config/nix/nix.conf`. Avoid generating a second NixOS user configuration unintentionally.
- The shared module declares `nix.package = pkgs.nix` to satisfy Home Manager's configuration assertion. It preserves `experimental-features = [ "nix-command" "flakes" ]` when Home Manager takes over the file bootstrap initially wrote.
- Apply `lib.mkForce` only to individual settings needing replacement (currently `substituters` and `experimental-features`), never the entire `nix.settings` attribute set. Keep `connect-timeout = 5` and `fallback = true` shared; `download-buffer-size = 524288000`, `auto-optimise-store = true` and `NIXPKGS_ALLOW_UNFREE` stay on the NixOS side.
- User substituters require daemon authorization on standalone multi-user installations; bootstrap writes the `meta.json` list daemon-side and never grants blanket `trusted-users` (write mechanics in [`docs/mirrors.md`](docs/mirrors.md)).
- `bootstrap/bootstrap.sh` is the **unified auto-detecting entry** (Darwin / NixOS / arch / sudo → dispatch to the three sub-scripts, which remain directly runnable; entry-level detection duplication is deliberate). All three chains tee their entire run to timestamped logs under `${XDG_STATE_HOME:-$HOME/.local/state}/nix-roam/`; token input goes through stdin and never enters a log.
- `bootstrap/linux.sh` (ordinary Linux/WSL, seven steps, multi/single-user install modes, interactive create-user flow), `bootstrap/darwin.sh` (Apple Silicon counterpart) and `bootstrap/nixos.sh` (`install` from live ISO / `adopt` on a running system, `--target` scaffolding) — chain-by-chain details live in [`docs/bootstrap.md`](docs/bootstrap.md).
- The script backs up real `.bashrc`, `.gitconfig`, `.ssh/config`, and `.profile` files with timestamp suffixes and skips symlinks. Home Manager uses `programs.ssh.enableDefaultConfig = false`; merge any required old SSH hosts into `home/common.nix` after migration. Open a new login shell after activation.
- Bootstrap is intended for repeat use but writes user `nix.conf` before activation. If Home Manager already owns it as a store symlink, all three bootstrap scripts detect the symlink and skip their appends (`darwin.sh` always did; `linux.sh` gained the same guards) — use Home Manager for routine updates; do not assume missing includes can be appended to a read-only managed file.
- Optional Nix GitHub tokens live in `~/.config/nix/github-access-tokens.conf` (0600), outside Git and the Nix store. `home/standalone-linux.nix` and `home/standalone-darwin.nix` retain the optional `!include`. Never inline tokens into Nix expressions. This file is separate from `gh auth login`, Git SSH keys, and Actions' ephemeral `GITHUB_TOKEN`.

## npm configuration ownership

Use `home.sessionVariables.NPM_CONFIG_REGISTRY` and the Bash `npmr` alias, rather than an HM-managed read-only `.npmrc`. `NPM_CONFIG_PREFIX` and `home.sessionPath` place global installs under `~/.npm-global/bin`. The registry environment variable overrides project/user `.npmrc`; use `--registry=<url>` or unset the variable for project-specific registries. The NJU alias is manual fallback, not automatic failover, and does not configure `sudo npm`. After activation, verify in a new shell with `npm config get registry` and `npmr config get registry`.

## Garbage collection

`roam gc` (folded in from the former `bootstrap/gc.sh` on 2026-09-28, the file deleted since — GC is a machine operation, not repo-touching, so it needs no checkout; direct-run equivalent `bash packages/roam.sh gc`) defaults to deleting generations older than 14 days; `--older-than Nd` changes retention, `--all` removes all non-current generations, and `--dry-run` only prints commands. Run as the normal user: it cleans the user first and uses sudo for system generations (automatic `--system` on NixOS); standalone/macOS require explicit `--system` for root/system cleanup. Referenced store paths remain; deleted generations lose rollback availability. gc does not refresh boot menus. Automatic GC (weekly `--delete-older-than 2w` + daily optimise + weekly user-generation cleanup) is configured on every NixOS host — desktop and WSL — through `profiles/nixos-base.nix` since 2026-09-26; `roam gc` stays the on-demand tool and remains the only option on standalone/macOS.

## Repository hosting and synchronization

- Gitee is the primary repository: `https://gitee.com/qihaoxu/nix-roam.git`; GitHub is `https://github.com/NoSeventh/nix-roam`. The Gitee repo is renamed to nix-roam (recorded 2026-09-29); the old name still resolves via Gitee's rename redirect, which is not durable — reference the new name only. `tests/repo-references.sh` gates fetchable old-name URLs to zero; the sanctioned exception is the bare-name alternation in each `bootstrap/*.sh` that recognizes existing old-name clones (do not "clean" those). Existing clones with an old-name remote keep working and remain recognized by bootstrap; `git remote set-url origin git@gitee.com:qihaoxu/nix-roam.git` is the recommended cleanup.
- Remote naming convention is `origin` (Gitee) and optional `github` (GitHub); `.git/config` is not shared by commits. A new clone has only its clone source as `origin`; inspect `git remote -v` before pushing.
- `.github/workflows/sync-from-gitee.yml` runs at minutes 17 and 47 each hour, via manual dispatch, and on pushes changing that workflow on `master`. It fetches public Gitee heads/tags with Git protocol v1 and up to four attempts, then pushes atomically using `GITHUB_TOKEN` with `contents: write`.
- Normal changes go to Gitee; Actions copies them to GitHub. No forced history updates or remote deletions; divergence and rewritten tags require intervention. This copies Git refs, not Issues, PRs, release assets or LFS objects.
- Keep workflow changes on both remotes using local credentials; the built-in token cannot push workflow-file changes. For public repositories, scheduled runs may be delayed and are disabled after 60 days without activity. Operational details: [`.github/SYNC.md`](.github/SYNC.md).
- **Agent auto-commit convention (2026-09-27, user instruction)**: change passes the agent considers reliable — verification complete, checks clean, no open questions — are committed directly at the end of the pass without a separate confirmation round; only unverified, risky or decision-pending changes stay uncommitted with a report. Automatic commits stop at `git commit`: pushing to remotes (`origin` = Gitee first) remains a manual, user-owned step.

## Validation boundaries

Dated verification records live in [`docs/VALIDATION.md`](docs/VALIDATION.md) (newest first) — one entry per change pass, stating what was actually evaluated / built / activated, on which host/distro, and what remains unverified. Append a new entry there when a change pass completes; this file keeps only the standing rules.

For documentation-only edits, check source consistency, local links, removed-path references and `git diff --check`; no system rebuild or activation is needed. For Nix changes, parse edited files, evaluate affected options/derivations, then build the appropriate target. Do not treat evaluation as a build, a build as activation, or a command found on the current host as proof of another target's package contents.
