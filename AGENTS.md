# AGENTS.md

A **dual-mode Nix flake** that supports two management modes from one source tree:

1. **NixOS mode** — desktop: `nixosConfigurations.nixos`; CLI-only WSL: `nixosConfigurations.wsl` (both x86_64-linux).
2. **Portable CLI mode** — user-level Home Manager only, for non-NixOS Linux / WSL / macOS. `homeConfigurations.xuqihao` (x86_64-linux), `xuqihao-aarch64` (aarch64-linux) and `xuqihao-darwin` (aarch64-darwin).

This file records the maintained architecture and operating conventions. Keep it and `README.md` aligned with implementation changes; historical plans are not required to work on this repository.

Standalone mode supplements the native package manager: keep system services and GUI applications under the native OS, with no root Home Manager profile or `darwinConfigurations`. Select explicit flake outputs; do not use `--impure`, environment variables or the evaluation host to choose a target. Standalone Linux ships explicit per-arch outputs — `xuqihao` (x86_64-linux) and `xuqihao-aarch64` (aarch64-linux) — selected by the arch-aware `hms` alias and `bootstrap/bootstrap.sh`, never by the evaluation host. The macOS output is aarch64-darwin only; NixOS outputs remain x86_64-linux.

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
| Existing Nix+HM macOS | `home-manager switch --flake .#xuqihao-darwin` |
| Existing Nix+HM Linux/WSL | `home-manager switch --flake .#xuqihao` (aarch64 hosts: `.#xuqihao-aarch64`, or just `hms`) |
| Remote (no clone) | `home-manager switch --flake "git+https://gitee.com/qihaoxu/nixos-niri-noctalia.git#xuqihao"` |

Aliases `nrs` and the IHEP/JUNO `ssh`/`sshfs`/distrobox aliases are defined in **`home/common.nix`** (`programs.bash.shellAliases`), not in a root `home.nix`; `hms` is a **shell function** in the same file (`programs.bash.initExtra` — the bash module has no `functions` option, that's zsh's). They are gated there: `hms` is **standalone-only** — injected via attrset-level `lib.optionalAttrs isStandalone` on the `programs.bash` attrset (never `lib.optionalString` on the option value: an explicitly-set empty `initExtra` renders a different bashrc — one extra blank line — than an unset one and needlessly shifts the whole NixOS closure hash), where `isStandalone` is passed by the flake (`true` from `mkStandaloneHome`, `false` from `nixosHome`), so NixOS hosts (desktop and WSL) don't get it at all and cannot accidentally activate a standalone profile; on standalone it picks the target from the host platform — `.#xuqihao` on x86_64 Linux, `.#xuqihao-aarch64` on aarch64 Linux, `.#xuqihao-darwin` on macOS (all derived from the single-point `username` in `meta.json`). `hms` first checks `id -un` and refuses with an explanatory message when the current login user differs from the configured username — running it by muscle memory on a machine with another login name fails cleanly instead of writing the profile into another user's HOME. `nrs` and the distrobox aliases are gated with `lib.optionalAttrs` too: the distrobox aliases are Linux-only, while `nrs` is **NixOS-only** (`isLinux && !isStandalone`) — on standalone the old `sudo nixos-rebuild` form was equally broken, so tightening the gate when nrs moved to nh is a fix, not a removal. `nrs` runs `nh os switch --diff always .` — nh is enabled via `programs.nh.enable` in `profiles/nixos-base.nix`, deliberately without `programs.nh.flake` (that would hardcode a checkout path; the alias passes the cwd-relative `.` instead) and without `nh clean` (GC stays with `bootstrap/gc.sh`). The relative flake path resolves against the current working directory, nh's `--hostname` defaults to the hostname which this repo's convention keeps equal to the output attribute (`.#wsl` on WSL, `.#nixos` on the desktop, and any scaffolded host follows directory name = hostname = output name), so it must be run from a checkout of this repository. nh handles privilege elevation itself (no `sudo` prefix in the alias) and prints an nvd package diff between generations after each switch. `nrs` in its nh form has not yet been exercised on a live NixOS host — see VALIDATION.md. There is no `nrrs` alias. Update flake dependencies with `nix flake update`, review and commit `flake.lock`, then build the affected targets; `nix-channel --update` does not update the lock file.

**Evaluation + build CI exists (`.github/workflows/eval.yml`); no other test framework.** The workflow evaluates the drvPath of all five outputs on pushes (after Gitee → GitHub sync), daily, and manually, **then builds the standalone Linux x86_64 activation package** (`nix build --no-link`, with a runner disk-cleanup step — the closure incl. C++ ROOT/toolchains is ~6-8GB). Evaluation catches upstream option removals; the build step catches eval-invisible failures — notably HM buildEnv conflicts (gcc+clang, dual `python3.withPackages`), which are exactly the historical breakages in this repo and are all build-time errors. NixOS toplevels stay eval-only (closures too large); aarch64 needs ARM hardware. Both layers are post-hoc, not a pre-push gate. Build without activation using `nix build --no-link` with the appropriate target:

- Desktop: `.#nixosConfigurations.nixos.config.system.build.toplevel`
- NixOS-WSL: `.#nixosConfigurations.wsl.config.system.build.toplevel`
- Standalone Linux: `.#homeConfigurations.xuqihao.activationPackage` (aarch64 output builds on ARM hardware; from x86_64 only `nix eval` works)

`nix run` on an activation package is not a dry build. A successful WSL build on another Linux distribution does not verify WSL boot or login.

## Architecture: one shared CLI list, four install sites

The core pattern. `packages/cli-dev.nix` is a **pure function** returning a cross-platform package list, imported in **four** places. Platform-specific packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` guards inside `cli-dev.nix`:

```
packages/cli-dev.nix         ({ pkgs, pkgs-stable, ... }: [ ... ])  cross-platform (platform-conditional inside)
        ├── profiles/cli.nix              → environment.systemPackages  (NixOS-WSL)
        ├── modules/desktop/programs.nix  → environment.systemPackages  (system-level, sudo-visible)
        ├── home/standalone-linux.nix     → home.packages               (user-level, non-NixOS Linux)
        └── home/standalone-darwin.nix    → home.packages               (user-level, macOS)
```

- **NixOS**: CLI tools land in `environment.systemPackages` → `/run/current-system/sw/bin` → inside sudo `secure_path`, so `sudo <tool>` works. This intentionally makes bare CLI tools available to root without a separate root profile.
- **Non-NixOS**: same list → `home.packages` → user profile. Home Manager does not configure sudoers; do not assume `sudo -E` bypasses the native sudo `secure_path`.
- **NixOS-only runtimes**: `profiles/nixos-base.nix` adds stable Node.js/npm, pnpm, R and a single stable Python scientific environment (including PyROOT) to both desktop and WSL. Python and PyROOT use the same Python package set; its wrapper sets the matching `R_HOME` for rpy2. Standalone Linux/Darwin do not explicitly install these runtimes; shared `packages/cli-dev.nix` retains standalone `uv`. The separate C++ ROOT application (`pkgs-stable.root`) remains in the shared Linux-only list for NixOS and standalone Linux, not Darwin. Internal interpreter dependencies of applications/editors are not project runtimes and should not be removed. npm registry/prefix configuration remains shared for natively installed Node.
- When adding a CLI tool, decide: needs a dotfile/HM module → `home/common.nix`; bare CLI binary → `packages/cli-dev.nix`. Don't duplicate between the two.
- Linux-only / Darwin-only packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` inside the main list.

## Home Manager layout (`home/`, not root `home.nix`)

| File | Role |
|---|---|
| `home/common.nix` | Cross-platform **CLI-only** HM core (git, bash, starship, helix, ssh, nixvim, fastfetch, btop dotfile). Imported by both modes. **Zero GUI assumptions.** |
| `home/nixos-cli.nix` | NixOS-WSL HM entry = `common.nix` + user identity. Shared CLI tools installed system-wide by `profiles/cli.nix`; development runtimes by `profiles/nixos-base.nix`. |
| `home/default.nix` | NixOS entry = `common.nix` + GUI terminals (alacritty/ghostty/fuzzel) + GUI dotfiles (kitty/wezterm terminals; niri/hypr compositor configs). |
| `home/standalone-linux.nix` | Non-NixOS Linux entry (both x86_64 and aarch64 use this module) = `common.nix` + `packages/cli-dev.nix`. Zero GUI. Idempotent activation scripts append guarded session-vars loaders to `~/.zshrc` (POSIX source) and fish config (`bass` if present, else PATH-only) — each gated on that shell being actually in use (login shell matches or the rc file already exists); rc files are never taken over and none are created for shells not in use. |
| `home/standalone-darwin.nix` | macOS entry = `common.nix` + `packages/cli-dev.nix`. Platform-conditional via `stdenv.hostPlatform.isDarwin`. Zero GUI. Keeps zsh native: no `programs.zsh`, never takes over `~/.zshrc`; an idempotent activation script appends a guarded `hm-session-vars.sh` loader so session variables/PATH load in zsh. |
| `home/nixvim.nix`, `home/fastfetch.nix` | Split sub-configs imported by `common.nix`. |

GUI HM config stays in `home/default.nix` only — **never** put GUI modules in `common.nix` (breaks WSL/macOS).

`flake.nix` wires it: `nixosHome` selects `home/default.nix` for the desktop and `home/nixos-cli.nix` for WSL; standalone mode uses `mkStandaloneHome` with platform-specific `standalone-{linux,darwin}.nix`. `home.username`/`homeDirectory`/`stateVersion` are injected by the flake (standalone via `mkStandaloneHome`, NixOS entries via `extraSpecialArgs`); `stateVersion` ("26.05") is itself single-pointed in `flake.nix`'s `let` and threaded to both `home.stateVersion` and `system.stateVersion` via `specialArgs`/`extraSpecialArgs`.

The local username is defined **once** — `username` in the repo-root **`meta.json`** (a data file, not Nix syntax, because the bootstrap scripts must read it *before* Nix exists; `flake.nix` loads it via `builtins.fromJSON (builtins.readFile ./meta.json)`, the scripts via a sed on a format we own) — and passed to every NixOS module and HM entry via `specialArgs`/`extraSpecialArgs`. `users.users.*`, `home-manager.users.*`, the standalone output names (`.#xuqihao`, `.#xuqihao-aarch64`, `.#xuqihao-darwin`) and the `hms` target all derive from it, so adopting a different login name is a one-line edit of `meta.json`. **No script falls back to a hardcoded username** — extraction failure aborts with an error (a silent fallback would quietly configure the wrong user after a reformat). Remote identities (IHEP/JUNO accounts, git email) in `home/common.nix` are personal remote accounts and deliberately do **not** derive from it.

## Directory structure

```
flake.nix                  # Explicit host/home outputs; pkgsFor instantiates unstable + stable per system (shared nixpkgsConfig)
meta.json                  # Single-point local username (read by flake.nix AND all bootstrap scripts — data file, not Nix)
profiles/                  # Explicit shared profiles: nixos-base, desktop, locale, CLI; hardware/ = dormant GPU/VM profiles
hosts/wsl/                 # NixOS-WSL entry, no physical hardware config
hosts/nixos/               # Current machine entry (host-specific settings) + tracked hardware-configuration.nix + variables.nix knobs
hosts/_template/           # New-host template (default/variables/hardware stub) — bootstrap scaffolds hosts/<hostname>/ from it
modules/                   # Shared NixOS modules (fix-network); modules/desktop/ = desktop-host-only modules
home/                      # Home Manager config (NixOS + standalone)
packages/cli-dev.nix       # Shared CLI tool list (pure function) — see architecture above
bootstrap/bootstrap.sh       # Unified auto-detecting entry (OS / NixOS / arch / sudo) dispatching to the scripts below
bootstrap/linux.sh         # Seven-step installer for standalone Linux/WSL (multi-user or single-user Nix install)
bootstrap/darwin.sh        # macOS counterpart (Apple Silicon only)
bootstrap/nixos.sh         # NixOS bootstrap: install (live ISO) / adopt (running system or NixOS-WSL)
bootstrap/gc.sh            # Manual GC with host detection and dry-run
dotfiles/                  # Raw config files, referenced via ../dotfiles from home/ and modules/
docs/VALIDATION.md         # Dated verification-boundary records (linked from the Validation section)
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

1. Copy `hosts/_template/` to `hosts/<hostname>/` and replace `__HOSTNAME__`. The convention is directory name = `networking.hostName` = output attribute name (so `nrs`/`nh` auto-match by hostname). Keep `profiles/desktop.nix` for a desktop or swap to `nixos-base.nix` + `cli.nix` for CLI-only; import one `profiles/hardware/*.nix` GPU/VM profile if the machine needs it.
2. Fill `variables.nix` knobs (`timeZone`, optional `gpuBusIDs`) and provide a real `hardware-configuration.nix` — the install chain regenerates it, adopting an existing system means copying that machine's current file in.
3. Add the `nixosConfigurations.<hostname>` output in `flake.nix` pointing at `./hosts/<hostname>` (copy the desktop or WSL block as appropriate; the scaffold prints both variants).
4. If the host needs a different HM user profile, pass a different module to `nixosHome`.
5. Build without activating via `nix build --no-link .#nixosConfigurations.<hostname>.config.system.build.toplevel` before the first `switch`; preserve that host's original `system.stateVersion` when adopting an existing system.

## Module loading: explicit imports everywhere

Both NixOS hosts import their modules explicitly through profiles — `flake.nix` does **not** scan `modules/` (no auto-loading). `modules/fix-network.nix` is shared (imported via `profiles/nixos-base.nix`); everything under `modules/desktop/` is desktop-host-only and imported explicitly by `profiles/desktop.nix`. Adding a module file changes nothing until it is added to the importing profile's list; likewise removing/renaming requires updating that list.

Module function signatures vary. For new edits, declare the parameters you use and retain `...`; some existing headers contain unused parameters. Referenced package sets must be in scope and supplied via module arguments. `modules/fix-network.nix` currently uses `{ ... }:` and only declares settings/imports.

Match the channel to the param you reference: `pkgs-stable` for stable, `pkgs` (unstable) for everything else. There is no `pkgs-master` — the master channel was removed on 2026-09-16 (it had no consumers); reintroduce it in `flake.nix` (`inputs` + `pkgsFor` + `specialArgs`) if ever needed.

Key modules (under `modules/desktop/` unless noted):
- `programs.nix` — giant GUI + CLI app list. Ends with `++ (import ../../packages/cli-dev.nix {...})`. Platform-conditional packages use `stdenv.hostPlatform.isLinux` guards. Also defines a **wechat overlay**.
- `niri.nix` — Niri (primary) + Hyprland + Sway fallbacks; `dms-shell` enabled as the shell.
- `agents.nix` — `hermes-agent` service + AI tools (cursor, claude-code, codex, opencode…). See "Secrets" below.
- `virtualization.nix` — Docker is the container engine (podman commented out; enable one or the other, never both). `services.nix` keeps rustdesk-server disabled until a real relay host replaces the old `example.com` placeholder.

## Two managed nixpkgs channels (plus nixvim's own)

- `nixpkgs` (unstable) → `pkgs`
- `nixpkgs-stable` (nixos-26.05) → `pkgs-stable`

`pkgsFor system` instantiates **both** channels under one shared `nixpkgsConfig` (`allowUnfree`, shared `permittedInsecurePackages`); `mkStandaloneHome` uses its `.unstable`/`.stable`, NixOS hosts receive `.stable` via `specialArgs`/`extraSpecialArgs` and provide their own unstable `pkgs` through `nixosSystem`. Standalone Linux per-arch outputs are explicit (`xuqihao` / `xuqihao-aarch64`) — there is no `forAllSystems` auto-expansion helper; adding a system means adding an explicit output.

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

`help.mirrors.cernet.edu.cn` (note the `s` — `help.mirror.cernet.edu.cn` does not resolve) is the CERNET 校园网联合镜像站 (MirrorZ). It is an **index/help aggregator, not a mirror itself**: it doesn't host packages, it points you at member mirrors (TUNA / USTC / NJU / SJTU / ...) and their per-project help pages. Never configure Nix to use `help.mirrors.cernet.edu.cn` or `mirrors.cernet.edu.cn` as a source.

- **Single source of truth** for Nix binary-cache substituters is `home/nix-cn.nix`, imported by `modules/fix-network.nix` (NixOS daemon) and both `home/standalone-*.nix` entries. Current list: NJU → TUNA → USTC → SJTU → `cache.nixos.org` fallback (ordered by 2026-08 measured latency).
- npm/npx 的 registry 统一在 `home/common.nix` 配置：默认 `NPM_CONFIG_REGISTRY=https://registry.npmmirror.com`（npmmirror）；A 不可用时用 bash 别名 `npmr` 切到 NJU 南大源（`https://repo.nju.edu.cn/repository/npm/`）。USTC 的 npm 反向代理已于 2026-06-12 停服（请求 302 → npmmirror），不要添加。
- **Keep `bootstrap/linux.sh` and `bootstrap/darwin.sh` in sync**: on non-NixOS multi-user installs (macOS included) the same list must be written to `/etc/nix/nix.custom.conf` as `trusted-substituters`, and `/etc/nix/nix.conf` must include that file — otherwise Nix ignores the user-level substituters with a warning. Single-user Linux installs (`NIX_INSTALL_MODE=single`) have no daemon and write the same list to the user-level `~/.config/nix/nix.conf` instead, where no trust grant is needed.
- Binary caches only cover store paths. Flake inputs (`github:nixos/nixpkgs/...`, `home-manager`, ...) still fetch source from GitHub; the nixpkgs **git** mirrors at USTC/SJTU are dead (404 as of 2026-08) — don't point flake inputs at them.
- SJTU is the only listed mirror providing nix-darwin binary cache (needed for `standalone-darwin`); TUNA/USTC/BFSU don't.
- BFSU's `/nix-channels/store` is a 302 redirect to TUNA, not an independent source — don't add it.

## Secrets

`modules/desktop/agents.nix` enables `services.hermes-agent` with `environmentFiles = [ "/etc/hermes/env" ];`. That file holds API keys (DeepSeek etc.) and is **not** in the repo — it must exist on the target machine or the service won't start with valid creds. `systemd.tmpfiles.rules` creates `/etc/hermes` (0750 root:hermes); `xuqihao` is added to the `hermes` group for shared-state access.

## Handling EOL / insecure packages

Inspect **both** `flake.nix` and `profiles/nixos-base.nix` when an insecure-package evaluation error occurs. Each nixpkgs instance has a separate allowlist; an exception on system unstable does not cover `pkgs-stable` or standalone unstable.

Current source values (not a claim that every target builds):

| nixpkgs instance | Location | `permittedInsecurePackages` |
|---|---|---|
| Stable **and** standalone unstable (shared) | `flake.nix` → `nixpkgsConfig` (consumed by `pkgsFor` for both channels) | — (none; `electron-38.8.4` removed 2026-09-17 after eval+build verified unreferenced) |
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
- The local username lives in one place: the repo-root `meta.json` (`{"username": "xuqihao"}`), read by `flake.nix` (fromJSON) and every bootstrap script (sed on a format we own, fail-loud). Everything else (`users.users.*`, `home-manager.users.*`, standalone output names, `hms` target, bootstrap password setup and default targets) derives from or reads that value; don't reintroduce hardcoded local usernames or silent fallbacks. Remote identities (IHEP/JUNO accounts, git email) in `home/common.nix` are separate.
- Adding an EOL exception → inspect **both** `flake.nix` and `profiles/nixos-base.nix` and update the affected nixpkgs instances; their current lists differ.

## NixOS-WSL

`hosts/wsl/default.nix` imports `profiles/nixos-base.nix` and `profiles/cli.nix`; the flake supplies NixOS-WSL and integrated Home Manager with `home/nixos-cli.nix`. Software tracks standalone Linux via the same list and common HM configuration. Do not import `home/standalone-linux.nix` into NixOS. Shared system settings belong in `profiles/`; desktop services stay in the desktop module set. NixOS-WSL does not require a generated physical hardware configuration.

“CLI-only” means shared base tools with standalone Linux, including tools such as mpv and the C++ ROOT application; do not remove packages merely because they can use graphics. Keep one shared CLI list and `home/common.nix`. Node/npm/pnpm and Python/PyROOT/R are an intentional NixOS-only addition through `profiles/nixos-base.nix`, identical on desktop and WSL. WSL uses system-level installation for bare tools and integrated Home Manager for user configuration; do not separately activate standalone Home Manager there.

Default WSL host/user are `wsl` / `xuqihao`. Activate explicitly with `sudo nixos-rebuild switch --flake .#wsl`. A freshly imported distro can be brought under this configuration by running `sudo bash bootstrap/nixos.sh` (auto-detected adopt → `.#wsl`). Shared defaults include `system.stateVersion = "26.05"`; preserve an existing target's original stateVersion when adopting this configuration. Desktop sessions, databases, container services, Hermes and remote mounts are not enabled by this entry; add services only when requested. WSLg integration follows NixOS-WSL defaults.

## Nix configuration ownership and bootstrap

- Keep `home/nix-cn.nix` out of `home/common.nix`: NixOS manages daemon settings through `profiles/nixos-base.nix` → `modules/fix-network.nix`, while standalone manages user `~/.config/nix/nix.conf`. Avoid generating a second NixOS user configuration unintentionally.
- The shared module declares `nix.package = pkgs.nix` to satisfy Home Manager's configuration assertion. It preserves `experimental-features = [ "nix-command" "flakes" ]` when Home Manager takes over the file bootstrap initially wrote.
- Apply `lib.mkForce` only to individual settings needing replacement (currently `substituters` and `experimental-features`), never the entire `nix.settings` attribute set. Keep `connect-timeout = 5` and `fallback = true` shared; `download-buffer-size = 524288000`, `auto-optimise-store = true` and `NIXPKGS_ALLOW_UNFREE` stay on the NixOS side.
- User substituters require daemon authorization on standalone multi-user installations. Bootstrap writes the four domestic caches as `trusted-substituters` and ensures `/etc/nix/nix.conf` includes `nix.custom.conf`; the official cache remains the shared fallback. It does not grant blanket `trusted-users` access. The skip checks in all bootstrap scripts only test for NJU, so changing the cache list also requires reviewing those checks (`bootstrap/nixos.sh` uses the same list for its bootstrap-time daemon config).
- `bootstrap/bootstrap.sh` is the **unified auto-detecting entry**: Darwin → `darwin.sh`; Linux with `/etc/NIXOS` → `nixos.sh` (re-exec'd via sudo when not root; mode/target still self-detected there); other Linux → `linux.sh` with the arch-derived default target. It carries the same outside-the-repo `CLONE_DIR` self-fetch as the sub-scripts, rejects WSL1 (kernel name without `microsoft-standard`) and unknown architectures up front, and prints an informational note for non-bash login shells. All three sub-scripts remain directly runnable; the entry only detects and dispatches, keeping detection logic duplicated (deliberately) with the sub-scripts' own guards. All three chains also tee their entire run to a timestamped log under `${XDG_STATE_HOME:-$HOME/.local/state}/nix-roam/` (`linux-*` / `darwin-*` / `nixos-*`), attached after the self-fetch re-exec so one-liner runs log at the final location too; `nixos.sh` runs as root, so its logs live under `/root/...`. Token input goes through stdin and never enters a log; the dispatcher itself does not wrap a tee (it execs into a sub-script immediately).
- `bootstrap/linux.sh [target]` is for ordinary Linux/WSL and runs seven steps: install Nix, configure mirrors, optionally store a GitHub token, enable flakes, back up conflicting files, install Home Manager, activate with `-b backup`. Do not use it for NixOS-WSL or for macOS. The default target is arch-derived from the single-point `username` in `meta.json` (`xuqihao` on x86_64, `xuqihao-aarch64` on aarch64; other architectures abort; extraction failure aborts — there is no hardcoded fallback). It rejects WSL1. Nix installation has two modes (`NIX_INSTALL_MODE=multi|single|auto`, default auto): `multi` (systemd present and `sudo -v` works) uses the Determinate Systems installer and writes daemon-side mirror trust to `/etc/nix`; `single` (no systemd or no sudo — also covers non-systemd distros like Artix/Devuan/Void) uses the official installer `--no-daemon` and writes mirrors to the user-level `~/.config/nix/nix.conf` plus an exported `NIX_CONFIG` for the session — the `/nix` prefix still requires one-time root creation, and the script prints the exact admin command instead of half-configuring when that's impossible. Steps 3/4 (token include, flakes) skip appends when the user `nix.conf` is already an HM-owned symlink, matching `darwin.sh`. The username guard strips `-aarch64`/`-darwin` suffixes before comparing with `id -un`. It also runs outside a checkout (the README curl one-liner or a standalone downloaded copy): it fetches the repo to `CLONE_DIR` (default `~/nix-roam`, overridable; git clone preferred, Gitee archive tarball when git is missing) and re-execs the in-repo copy. Both standalone bootstraps abort up front when the target's username differs from the current login user (standalone Home Manager can only activate for the current user), with a hint pointing at the one-line `username` edit in `meta.json` — this prevents the half-configured state of system nix settings being rewritten before activation fails on someone else's HOME.
- `bootstrap/darwin.sh [target]` is the macOS counterpart, defaulting to `<meta.json username>-darwin` (same extraction pattern as the other scripts, fail-loud): same seven steps and Determinate Systems installer, guarded to Apple Silicon (`uname -s` = Darwin and `uname -m` = arm64; Intel Macs are rejected because the flake only outputs aarch64-darwin). It supports the same outside-the-repo one-liner and `CLONE_DIR` self-fetch as `linux.sh`. macOS differences: in-place edits use BSD `sed -i ''`; user-level `nix.conf` appends (token include, `experimental-features`) are skipped when the file is already a Home Manager-owned symlink — the token include is carried by `home/standalone-darwin.nix`'s `nix.extraOptions`, flakes by `nix-cn.nix`. It installs no nix-darwin and manages no system services or GUI; it has not yet been run on a real macOS host. macOS conventions are preserved: the default shell stays zsh, `~/.zshrc` is never taken over (only the guarded hm-session-vars append described above), and Homebrew coexists with nix paths taking PATH precedence.
- `bootstrap/nixos.sh [install|adopt] [--target <hostname>]` bootstraps the NixOS side and must run as root. `install` runs inside the live ISO with the target mounted at `/mnt` — partitioning/formatting is deliberately out of scope (reference commands live in the script header); `adopt` runs on an installed NixOS or a freshly imported NixOS-WSL. Mode is auto-detected via `/etc/NIXOS`, target via the WSL kernel marker; WSL has no `install` chain. `--target` accepts any `[a-zA-Z0-9-]` hostname: when `hosts/<target>/` is missing, the script scaffolds it from `hosts/_template/` (replacing `__HOSTNAME__`), prints paste-ready desktop/CLI flake output blocks, waits for the manual `flake.nix` paste and verifies the output exists before continuing — it never edits `flake.nix` itself. `install` re-runs `nixos-generate-config --root /mnt` every time, moves the result into `hosts/<target>/hardware-configuration.nix` (previous copy backed up alongside with a timestamp — commit the regenerated file back to Gitee), requires a `/boot` entry (systemd-boot) and sets the configured user's password via `nixos-enter` because the flake defines no password fields (the username is read from `meta.json`'s single-point `username`; extraction failure aborts — the old `xuqihao` fallback is gone). `adopt` backs up a foreign `/etc/nixos` wholesale and aborts on a stateVersion mismatch unless explicitly confirmed. Mirrors/token are bootstrap-time only, delivered daemon-side through `/etc/nix/nix.custom.conf` plus an exported `NIX_CONFIG` — an `nix.settings`-managed `/etc/nix/nix.conf` is a store symlink that cannot be appended to; after adoption `modules/fix-network.nix` → `home/nix-cn.nix` takes over as the single source. Neither chain has been exercised on real hardware yet.
- The script backs up real `.bashrc`, `.gitconfig`, `.ssh/config`, and `.profile` files with timestamp suffixes and skips symlinks. Home Manager uses `programs.ssh.enableDefaultConfig = false`; merge any required old SSH hosts into `home/common.nix` after migration. Open a new login shell after activation.
- Bootstrap is intended for repeat use but writes user `nix.conf` before activation. If Home Manager already owns it as a store symlink, all three bootstrap scripts detect the symlink and skip their appends (`darwin.sh` always did; `linux.sh` gained the same guards) — use Home Manager for routine updates; do not assume missing includes can be appended to a read-only managed file.
- Optional Nix GitHub tokens live in `~/.config/nix/github-access-tokens.conf` (0600), outside Git and the Nix store. `home/standalone-linux.nix` and `home/standalone-darwin.nix` retain the optional `!include`. Never inline tokens into Nix expressions. This file is separate from `gh auth login`, Git SSH keys, and Actions' ephemeral `GITHUB_TOKEN`.

## npm configuration ownership

Use `home.sessionVariables.NPM_CONFIG_REGISTRY` and the Bash `npmr` alias, rather than an HM-managed read-only `.npmrc`. `NPM_CONFIG_PREFIX` and `home.sessionPath` place global installs under `~/.npm-global/bin`. The registry environment variable overrides project/user `.npmrc`; use `--registry=<url>` or unset the variable for project-specific registries. The NJU alias is manual fallback, not automatic failover, and does not configure `sudo npm`. After activation, verify in a new shell with `npm config get registry` and `npmr config get registry`.

## Garbage collection

`bootstrap/gc.sh` defaults to deleting generations older than 14 days; `--older-than Nd` changes retention, `--all` removes all non-current generations, and `--dry-run` only prints commands. Run as the normal user: it cleans the user first and uses sudo for NixOS system generations; standalone/macOS require `--system` for root/system cleanup. Referenced store paths remain; deleted generations lose rollback availability. The script does not refresh boot menus or configure automatic GC.

## Repository hosting and synchronization

- Gitee is the primary repository: `https://gitee.com/qihaoxu/nixos-niri-noctalia.git`; GitHub is `https://github.com/NoSeventh/nix-roam`. The project is named nix-roam, but the Gitee path retains the older name.
- Remote naming convention is `origin` (Gitee) and optional `github` (GitHub); `.git/config` is not shared by commits. A new clone has only its clone source as `origin`; inspect `git remote -v` before pushing.
- `.github/workflows/sync-from-gitee.yml` runs at minutes 17 and 47 each hour, via manual dispatch, and on pushes changing that workflow on `master`. It fetches public Gitee heads/tags with Git protocol v1 and up to four attempts, then pushes atomically using `GITHUB_TOKEN` with `contents: write`.
- Normal changes go to Gitee; Actions copies them to GitHub. No forced history updates or remote deletions; divergence and rewritten tags require intervention. This copies Git refs, not Issues, PRs, release assets or LFS objects.
- Keep workflow changes on both remotes using local credentials; the built-in token cannot push workflow-file changes. For public repositories, scheduled runs may be delayed and are disabled after 60 days without activity. Operational details: [`.github/SYNC.md`](.github/SYNC.md).

## Validation boundaries

Dated verification records live in [`docs/VALIDATION.md`](docs/VALIDATION.md) (newest first) — one entry per change pass, stating what was actually evaluated / built / activated, on which host/distro, and what remains unverified. Append a new entry there when a change pass completes; this file keeps only the standing rules.

For documentation-only edits, check source consistency, local links, removed-path references and `git diff --check`; no system rebuild or activation is needed. For Nix changes, parse edited files, evaluate affected options/derivations, then build the appropriate target. Do not treat evaluation as a build, a build as activation, or a command found on the current host as proof of another target's package contents.
