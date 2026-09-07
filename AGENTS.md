# AGENTS.md

A **dual-mode Nix flake** that supports two management modes from one source tree:

1. **NixOS mode** — desktop: `nixosConfigurations.nixos`; CLI-only WSL: `nixosConfigurations.wsl` (both x86_64-linux).
2. **Portable CLI mode** — user-level Home Manager only, for non-NixOS Linux / WSL / macOS. `homeConfigurations.xuqihao` / `xuqihao-darwin`.

This file records the maintained architecture and operating conventions. Keep it and `README.md` aligned with implementation changes; historical plans are not required to work on this repository.

Standalone mode supplements the native package manager: keep system services and GUI applications under the native OS, with no root Home Manager profile or `darwinConfigurations`. Select explicit flake outputs; do not use `--impure`, environment variables or the evaluation host to choose a target. Linux outputs are x86_64-linux; the macOS output is aarch64-darwin only.

## Detect the current host before acting

This repository defines both NixOS and standalone Home Manager targets; **the target present in the repo does not identify the environment where an agent is currently running**. Before diagnosing, rebuilding, activating, or editing environment-specific settings, inspect the actual host (at minimum `/etc/os-release`, `uname -a`, and whether `/etc/NIXOS` exists).

- `/etc/NIXOS` exists → current host is NixOS; system fixes belong under `hosts/`, `profiles/`, or `modules/` (desktop-only modules under `modules/desktop/`), and activation uses `nixos-rebuild`.
- `/etc/NIXOS` absent → current host is standalone Nix on Linux/WSL (or macOS); fixes belong under `home/standalone-*`, `home/common.nix`, or `bootstrap/` as appropriate, and activation uses Home Manager.
- WSL with `/etc/NIXOS` is NixOS-WSL and uses `.#wsl`; other WSL distributions use standalone Home Manager.
- Never infer the current host from the working directory, hostname, flake outputs, `/run/current-system` alone, or wording such as “this machine” in older documentation. State the detected environment before choosing a mode-specific fix.

## Build & activate commands

| Target | Command |
|---|---|
| NixOS desktop | `sudo nixos-rebuild switch --flake .#nixos` |
| NixOS-WSL | `sudo nixos-rebuild switch --flake .#wsl` |
| Fresh NixOS desktop (live ISO) | `bash bootstrap/nixos.sh install` (root in the installer; `/mnt` pre-mounted) |
| Existing NixOS / NixOS-WSL | `sudo bash bootstrap/nixos.sh` (auto-detects adopt; WSL → `.#wsl`) |
| Fresh Linux/WSL (no Nix yet) | `bash bootstrap/linux.sh` (installs Nix + HM, then activates) |
| Fresh macOS (no Nix yet) | `bash bootstrap/darwin.sh` (installs Nix + HM, then activates) |
| Existing Nix+HM macOS | `home-manager switch --flake .#xuqihao-darwin` |
| Existing Nix+HM Linux/WSL | `home-manager switch --flake .#xuqihao` |
| Remote (no clone) | `home-manager switch --flake "git+https://gitee.com/qihaoxu/nixos-niri-noctalia.git#xuqihao"` |

Aliases `nrs` / `hms` and the IHEP/JUNO `ssh`/`sshfs`/distrobox aliases are defined in **`home/common.nix`** (`programs.bash.shellAliases`), not in a root `home.nix`. They are platform-gated there: `hms` picks `.#xuqihao` on Linux and `.#xuqihao-darwin` on macOS (never NixOS-WSL); `nrs` and the distrobox aliases are Linux-only via `lib.optionalAttrs`. `nrs` has no explicit flake target; use the commands above for a specific host. There is no `nrrs` alias. Update flake dependencies with `nix flake update`, review and commit `flake.lock`, then build the affected targets; `nix-channel --update` does not update the lock file.

**No repository test framework.** Build without activation using `nix build --no-link` with the appropriate target:

- Desktop: `.#nixosConfigurations.nixos.config.system.build.toplevel`
- NixOS-WSL: `.#nixosConfigurations.wsl.config.system.build.toplevel`
- Standalone Linux: `.#homeConfigurations.xuqihao.activationPackage`

`nix run` on an activation package is not a dry build. A successful WSL build on another Linux distribution does not verify WSL boot or login.

## Architecture: one shared CLI list, four install sites

The core pattern. `packages/cli-dev.nix` is a **pure function** returning a cross-platform package list, imported in **four** places. Platform-specific packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` guards inside `cli-dev.nix`:

```
packages/cli-dev.nix         ({ pkgs, pkgs-stable, pkgs-master, ... }: [ ... ])  cross-platform (platform-conditional inside)
        ├── profiles/cli.nix              → environment.systemPackages  (NixOS-WSL)
        ├── modules/desktop/programs.nix  → environment.systemPackages  (system-level, sudo-visible)
        ├── home/standalone-linux.nix     → home.packages               (user-level, non-NixOS Linux)
        └── home/standalone-darwin.nix    → home.packages               (user-level, macOS)
```

- **NixOS**: CLI tools land in `environment.systemPackages` → `/run/current-system/sw/bin` → inside sudo `secure_path`, so `sudo <tool>` works. This intentionally makes bare CLI tools available to root without a separate root profile.
- **Non-NixOS**: same list → `home.packages` → user profile. Home Manager does not configure sudoers; do not assume `sudo -E` bypasses the native sudo `secure_path`.
- When adding a CLI tool, decide: needs a dotfile/HM module → `home/common.nix`; bare CLI binary → `packages/cli-dev.nix`. Don't duplicate between the two.
- Linux-only / Darwin-only packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` inside the main list.

## Home Manager layout (`home/`, not root `home.nix`)

| File | Role |
|---|---|
| `home/common.nix` | Cross-platform **CLI-only** HM core (git, bash, starship, helix, ssh, nixvim, fastfetch, btop dotfile). Imported by both modes. **Zero GUI assumptions.** |
| `home/nixos-cli.nix` | NixOS-WSL HM entry = `common.nix` + user identity. CLI packages installed system-wide by `profiles/cli.nix`. |
| `home/default.nix` | NixOS entry = `common.nix` + GUI terminals (alacritty/ghostty/fuzzel) + GUI terminal dotfiles (kitty/wezterm). |
| `home/standalone-linux.nix` | Non-NixOS Linux entry = `common.nix` + `packages/cli-dev.nix`. Platform-conditional via `stdenv.hostPlatform.isLinux`. Zero GUI. |
| `home/standalone-darwin.nix` | macOS entry = `common.nix` + `packages/cli-dev.nix`. Platform-conditional via `stdenv.hostPlatform.isDarwin`. Zero GUI. Keeps zsh native: no `programs.zsh`, never takes over `~/.zshrc`; an idempotent activation script appends a guarded `hm-session-vars.sh` loader so session variables/PATH load in zsh. |
| `home/nixvim.nix`, `home/fastfetch.nix` | Split sub-configs imported by `common.nix`. |

GUI HM config stays in `home/default.nix` only — **never** put GUI modules in `common.nix` (breaks WSL/macOS).

`flake.nix` wires it: `nixosHome` selects `home/default.nix` for the desktop and `home/nixos-cli.nix` for WSL; standalone mode uses `mkStandaloneHome` with platform-specific `standalone-{linux,darwin}.nix`. `home.username`/`homeDirectory`/`stateVersion` are injected by the flake for standalone mode.

## Directory structure

```
flake.nix                  # Explicit host/home outputs; pkgsFor creates stable/master per system
profiles/                  # Explicit shared profiles: nixos-base, desktop, locale, CLI
hosts/wsl/                 # NixOS-WSL entry, no physical hardware config
hosts/nixos/               # Current machine entry (host-specific settings) + tracked hardware-configuration.nix
modules/                   # Shared NixOS modules (fix-network); modules/desktop/ = desktop-host-only modules
home/                      # Home Manager config (NixOS + standalone)
packages/cli-dev.nix       # Shared CLI tool list (pure function) — see architecture above
bootstrap/linux.sh         # Seven-step installer for standalone Linux/WSL
bootstrap/darwin.sh        # macOS counterpart (Apple Silicon only)
bootstrap/nixos.sh         # NixOS bootstrap: install (live ISO) / adopt (running system or NixOS-WSL)
bootstrap/gc.sh            # Manual GC with host detection and dry-run
dotfiles/                  # Raw config files, referenced via ../dotfiles from home/ and modules/
AGENTS.md                  # Maintained architecture and operating conventions
.github/workflows/         # Gitee → GitHub synchronization
.github/SYNC.md            # Synchronization operation and limitations
```

## Host layout

`hosts/nixos/default.nix` is the current machine entry: it imports `profiles/desktop.nix` and its tracked `hardware-configuration.nix`, and holds only machine-specific settings (boot/loader, kernel, `networking.hostName`, power/lid policy, user groups, sshd). There is no root `configuration.nix`. Keep generated hardware files under `hosts/<hostname>/` and track them so Git Flake evaluation remains pure and reproducible; the root `/hardware-configuration.nix` path is ignored only to prevent accidental regeneration in the wrong location.

**Adding a new machine:**

1. Create `hosts/<hostname>/default.nix` importing the appropriate profiles (`profiles/nixos-base.nix` for a CLI-only host, `profiles/desktop.nix` for a desktop — it imports `nixos-base.nix` itself) plus `./hardware-configuration.nix`, and put host-specific settings (boot, hostname, hardware quirks) directly in it.
2. Add a `nixosConfigurations.<hostname>` output in `flake.nix` pointing at `./hosts/<hostname>` (copy the desktop or WSL block as appropriate).
3. If the host needs a different HM user profile, pass a different module to `nixosHome`.
4. Build without activating via `nix build --no-link .#nixosConfigurations.<hostname>.config.system.build.toplevel` before the first `switch`; preserve that host's original `system.stateVersion` when adopting an existing system.

## Module loading: explicit imports everywhere

Both NixOS hosts import their modules explicitly through profiles — `flake.nix` does **not** scan `modules/` (no auto-loading). `modules/fix-network.nix` is shared (imported via `profiles/nixos-base.nix`); everything under `modules/desktop/` is desktop-host-only and imported explicitly by `profiles/desktop.nix`. Adding a module file changes nothing until it is added to the importing profile's list; likewise removing/renaming requires updating that list.

Module function signatures vary. For new edits, declare the parameters you use and retain `...`; some existing headers contain unused parameters. Referenced package sets must be in scope and supplied via module arguments. `modules/fix-network.nix` currently uses `{ ... }:` and only declares settings/imports.

Match the channel to the param you reference: `pkgs-stable` for stable, `pkgs-master` for master, `pkgs` (unstable) for everything else.

Key modules (under `modules/desktop/` unless noted):
- `programs.nix` — giant GUI + CLI app list. Ends with `++ (import ../../packages/cli-dev.nix {...})`. Platform-conditional packages use `stdenv.hostPlatform.isLinux` guards. Also defines a **wechat overlay**.
- `niri.nix` — Niri (primary) + Hyprland + Sway fallbacks; `dms-shell` enabled as the shell.
- `agents.nix` — `hermes-agent` service + AI tools (cursor, claude-code, codex, opencode…). See "Secrets" below.
- `virtualization.nix` — Docker **and** Podman both enabled; don't point both at the same containers.

## Three nixpkgs channels

- `nixpkgs` (unstable) → `pkgs`
- `nixpkgs-stable` (nixos-26.05) → `pkgs-stable`
- `nixpkgs-master` → `pkgs-master` (wired into `specialArgs`; use sparingly)

NixOS provides its own unstable `pkgs`; `mkStandaloneHome` imports unstable for standalone. `pkgsFor` separately instantiates stable/master per system and passes them via `specialArgs` / `extraSpecialArgs`. The `supportedSystems` / `forAllSystems` helper is currently unused; editing that list alone does not add an output. Convention: heavy/stability-sensitive packages (editors, office, toolchains) on `pkgs-stable.`; bleeding-edge stuff on `pkgs`.

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
- **Keep `bootstrap/linux.sh` and `bootstrap/darwin.sh` in sync**: on non-NixOS multi-user installs (macOS included) the same list must be written to `/etc/nix/nix.custom.conf` as `trusted-substituters`, and `/etc/nix/nix.conf` must include that file. Otherwise Nix ignores the user-level substituters with a warning.
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
| Stable, all targets | `flake.nix` → `pkgsFor.stable` | `electron-38.8.4` |
| Standalone unstable | `flake.nix` → `mkStandaloneHome` | `electron-38.8.4` |
| NixOS unstable, desktop/WSL | `profiles/nixos-base.nix` | `electron-40.10.5`, `pnpm-10.29.2` |
| Master | `flake.nix` → `pkgsFor.master` | No explicit allowlist |

These lists currently differ. Add an approved exact package/version exception to every affected instance in both files as needed; do not assume one edit covers all four outputs or expand permissions just to make documentation match. Validate the affected package/target after changing exceptions.

## buildEnv conflict gotchas (in `packages/cli-dev.nix`)

Hard-won — read the header comments there before editing that file:
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
- GUI HM modules → `home/default.nix` only; CLI → `home/common.nix` (needs config) or `packages/cli-dev.nix` (bare tool); Linux-only/Darwin-only packages use `lib.optionals stdenv.hostPlatform.isLinux` / `stdenv.hostPlatform.isDarwin` inside `cli-dev.nix`.
- Don't uncomment the `noctalia`/`dms`/`quickshell` inputs — those packages now come from nixpkgs unstable (`chaotic` removed).
- Adding an EOL exception → inspect **both** `flake.nix` and `profiles/nixos-base.nix` and update the affected nixpkgs instances; their current lists differ.

## NixOS-WSL

`hosts/wsl/default.nix` imports `profiles/nixos-base.nix` and `profiles/cli.nix`; the flake supplies NixOS-WSL and integrated Home Manager with `home/nixos-cli.nix`. Software tracks standalone Linux via the same list and common HM configuration. Do not import `home/standalone-linux.nix` into NixOS. Shared system settings belong in `profiles/`; desktop services stay in the desktop module set. NixOS-WSL does not require a generated physical hardware configuration.

“CLI-only” means software alignment with standalone Linux, including tools such as mpv; do not remove packages merely because they can use graphics. Keep one shared CLI list and `home/common.nix`. WSL uses system-level installation for bare tools and integrated Home Manager for user configuration; do not separately activate standalone Home Manager there.

Default WSL host/user are `wsl` / `xuqihao`. Activate explicitly with `sudo nixos-rebuild switch --flake .#wsl`. A freshly imported distro can be brought under this configuration by running `sudo bash bootstrap/nixos.sh` (auto-detected adopt → `.#wsl`). Shared defaults include `system.stateVersion = "26.05"`; preserve an existing target's original stateVersion when adopting this configuration. Desktop sessions, databases, container services, Hermes and remote mounts are not enabled by this entry; add services only when requested. WSLg integration follows NixOS-WSL defaults.

## Nix configuration ownership and bootstrap

- Keep `home/nix-cn.nix` out of `home/common.nix`: NixOS manages daemon settings through `profiles/nixos-base.nix` → `modules/fix-network.nix`, while standalone manages user `~/.config/nix/nix.conf`. Avoid generating a second NixOS user configuration unintentionally.
- The shared module declares `nix.package = pkgs.nix` to satisfy Home Manager's configuration assertion. It preserves `experimental-features = [ "nix-command" "flakes" ]` when Home Manager takes over the file bootstrap initially wrote.
- Apply `lib.mkForce` only to individual settings needing replacement (currently `substituters` and `experimental-features`), never the entire `nix.settings` attribute set. Keep `connect-timeout = 5` and `fallback = true` shared; `download-buffer-size = 524288000`, `auto-optimise-store = true` and `NIXPKGS_ALLOW_UNFREE` stay on the NixOS side.
- User substituters require daemon authorization on standalone multi-user installations. Bootstrap writes the four domestic caches as `trusted-substituters` and ensures `/etc/nix/nix.conf` includes `nix.custom.conf`; the official cache remains the shared fallback. It does not grant blanket `trusted-users` access. The skip checks in all bootstrap scripts only test for NJU, so changing the cache list also requires reviewing those checks (`bootstrap/nixos.sh` uses the same list for its bootstrap-time daemon config).
- `bootstrap/linux.sh [target]` is for ordinary Linux/WSL, defaults to `xuqihao`, and runs seven steps: install Nix, configure cache trust, optionally store a GitHub token, enable flakes, back up conflicting files, install Home Manager, activate with `-b backup`. Do not use it for NixOS-WSL or for macOS.
- `bootstrap/darwin.sh [target]` is the macOS counterpart, defaults to `xuqihao-darwin`: same seven steps and Determinate Systems installer, guarded to Apple Silicon (`uname -s` = Darwin and `uname -m` = arm64; Intel Macs are rejected because the flake only outputs aarch64-darwin). macOS differences: in-place edits use BSD `sed -i ''`; user-level `nix.conf` appends (token include, `experimental-features`) are skipped when the file is already a Home Manager-owned symlink — the token include is carried by `home/standalone-darwin.nix`'s `nix.extraOptions`, flakes by `nix-cn.nix`. It installs no nix-darwin and manages no system services or GUI; it has not yet been run on a real macOS host. macOS conventions are preserved: the default shell stays zsh, `~/.zshrc` is never taken over (only the guarded hm-session-vars append described above), and Homebrew coexists with nix paths taking PATH precedence.
- `bootstrap/nixos.sh [install|adopt] [--target nixos|wsl]` bootstraps the NixOS side and must run as root. `install` runs inside the live ISO with the target mounted at `/mnt` — partitioning/formatting is deliberately out of scope (reference commands live in the script header); `adopt` runs on an installed NixOS or a freshly imported NixOS-WSL. Mode is auto-detected via `/etc/NIXOS`, target via the WSL kernel marker; WSL has no `install` chain. `install` re-runs `nixos-generate-config --root /mnt` every time, moves the result into `hosts/nixos/hardware-configuration.nix` (previous copy backed up alongside with a timestamp — commit the regenerated file back to Gitee), requires a `/boot` entry (systemd-boot) and sets `xuqihao`'s password via `nixos-enter` because the flake defines no password fields. `adopt` backs up a foreign `/etc/nixos` wholesale and aborts on a stateVersion mismatch unless explicitly confirmed. Mirrors/token are bootstrap-time only, delivered daemon-side through `/etc/nix/nix.custom.conf` plus an exported `NIX_CONFIG` — an `nix.settings`-managed `/etc/nix/nix.conf` is a store symlink that cannot be appended to; after adoption `modules/fix-network.nix` → `home/nix-cn.nix` takes over as the single source. Neither chain has been exercised on real hardware yet.
- The script backs up real `.bashrc`, `.gitconfig`, `.ssh/config`, and `.profile` files with timestamp suffixes and skips symlinks. Home Manager uses `programs.ssh.enableDefaultConfig = false`; merge any required old SSH hosts into `home/common.nix` after migration. Open a new login shell after activation.
- Bootstrap is intended for repeat use but writes user `nix.conf` before activation. If Home Manager already owns it as a store symlink, use Home Manager for routine updates; do not assume missing includes can be appended to a read-only managed file.
- Optional Nix GitHub tokens live in `~/.config/nix/github-access-tokens.conf` (0600), outside Git and the Nix store. `home/standalone-linux.nix` and `home/standalone-darwin.nix` retain the optional `!include`. Never inline tokens into Nix expressions. This file is separate from `gh auth login`, Git SSH keys, and Actions' ephemeral `GITHUB_TOKEN`.

## npm configuration ownership

Use `home.sessionVariables.NPM_CONFIG_REGISTRY` and the Bash `npmr` alias, rather than an HM-managed read-only `.npmrc`. `NPM_CONFIG_PREFIX` and `home.sessionPath` place global installs under `~/.npm-global/bin`. The registry environment variable overrides project/user `.npmrc`; use `--registry=<url>` or unset the variable for project-specific registries. The NJU alias is manual fallback, not automatic failover, and does not configure `sudo npm`. After activation, verify in a new shell with `npm config get registry` and `npmr config get registry`.

## Garbage collection

`bootstrap/gc.sh` defaults to deleting generations older than 14 days; `--older-than Nd` changes retention, `--all` removes all non-current generations, and `--dry-run` only prints commands. Run as the normal user: it cleans the user first and uses sudo for NixOS system generations; standalone/macOS require `--system` for root/system cleanup. Referenced store paths remain; deleted generations lose rollback availability. The script does not refresh boot menus or configure automatic GC.

## Repository hosting and synchronization

- Gitee is the primary repository: `https://gitee.com/qihaoxu/nixos-niri-noctalia.git`; GitHub is `https://github.com/NoSeventh/nix-roam`. The project is named nix-roam, but the Gitee path retains the older name.
- Local remotes are `origin` (Gitee) and `github` (GitHub); `.git/config` is not shared by commits. A new clone has only its clone source as `origin`; inspect `git remote -v` before pushing.
- `.github/workflows/sync-from-gitee.yml` runs at minutes 17 and 47 each hour, via manual dispatch, and on pushes changing that workflow on `master`. It fetches public Gitee heads/tags with Git protocol v1 and up to four attempts, then pushes atomically using `GITHUB_TOKEN` with `contents: write`.
- Normal changes go to Gitee; Actions copies them to GitHub. No forced history updates or remote deletions; divergence and rewritten tags require intervention. This copies Git refs, not Issues, PRs, release assets or LFS objects.
- Keep workflow changes on both remotes using local credentials; the built-in token cannot push workflow-file changes. For public repositories, scheduled runs may be delayed and are disabled after 60 days without activity. Operational details: [`.github/SYNC.md`](.github/SYNC.md).

## Validation boundaries

For documentation-only edits, check source consistency, local links, removed-path references and `git diff --check`; no system rebuild or activation is needed. For Nix changes, parse edited files, evaluate affected options/derivations, then build the appropriate target. Do not treat evaluation as a build, a build as activation, or a command found on the current host as proof of another target's package contents.

Historical verification on 2026-09-05 used AlmaLinux 9.8 / WSL2 standalone Nix: WSL's system closure built; the desktop host-layout refactor preserved its derivation; standalone Linux/Darwin activation derivations evaluated. These records predate later edits and do not certify the current lock/package set. Real NixOS-WSL boot/login/switch and a Darwin build remain unverified. GitHub synchronization was separately verified by pushing a documentation commit only to Gitee and observing Actions update GitHub.
