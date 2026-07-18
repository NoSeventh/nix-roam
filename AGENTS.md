# AGENTS.md

A **dual-mode Nix flake** that serves two targets from one source tree:

1. **NixOS mode** — full system config (desktop, GUI apps, services). `nixosConfigurations.nixos` (x86_64-linux).
2. **Portable CLI mode** — user-level Home Manager only, for non-NixOS Linux / WSL / macOS. `homeConfigurations.xuqihao` / `xuqihao-darwin`.

Read `docs/superpowers/specs/2026-07-06-dual-mode-flake-design.md` for the design rationale before restructuring the flake.

## Build & activate commands

| Target | Command |
|---|---|
| NixOS (this machine) | `sudo nixos-rebuild switch` (alias `nrs`) |
| NixOS + channel update | `nrrs` (= `sudo nix-channel --update && sudo nixos-rebuild switch`) |
| Fresh Linux/WSL (no Nix yet) | `bash bootstrap/linux.sh` (installs Nix + HM, then activates) |
| Existing Nix+HM Linux/WSL | `home-manager switch --flake .#xuqihao` |
| Remote (no clone) | `home-manager switch --flake "git+https://gitee.com/qihaoxu/nixos-niri-noctalia#xuqihao"` |

Aliases `nrs` / `nrrs` and the IHEP/JUNO `ssh`/`sshfs`/distrobox aliases are defined in **`home/common.nix`** (`programs.bash.shellAliases`), not in a root `home.nix`.

**No test framework.** Verify by rebuilding and checking system behavior. To check a flake builds without switching: `nix build .#nixosConfigurations.nixos.config.system.build.toplevel` (NixOS) or `nix run .#homeConfigurations.xuqihao.activationPackage` (HM, dry).

## Architecture: one shared CLI list, three install sites

The core pattern. `packages/cli-dev.nix` is a **pure function** returning a cross-platform package list, imported in **three** places. Platform-specific packages use `lib.optionals stdenv.isLinux` / `stdenv.isDarwin` guards inside `cli-dev.nix`:

```
packages/cli-dev.nix         ({ pkgs, pkgs-stable }: [ ... ])  cross-platform (platform-conditional inside)
        ├── modules/programs.nix          → environment.systemPackages  (system-level, sudo-visible)
        ├── home/standalone-linux.nix     → home.packages               (user-level, non-NixOS Linux)
        └── home/standalone-darwin.nix    → home.packages               (user-level, macOS)
```

- **NixOS**: CLI tools land in `environment.systemPackages` → `/run/current-system/sw/bin` → inside sudo `secure_path`, so `sudo <tool>` works. This is intentional (see design doc §9).
- **Non-NixOS**: same list → `home.packages` → user profile.
- When adding a CLI tool, decide: needs a dotfile/HM module → `home/common.nix`; bare CLI binary → `packages/cli-dev.nix`. Don't duplicate between the two.
- Linux-only / Darwin-only packages use `lib.optionals stdenv.isLinux` / `stdenv.isDarwin` inside the main list.

## Home Manager layout (`home/`, not root `home.nix`)

| File | Role |
|---|---|
| `home/common.nix` | Cross-platform **CLI-only** HM core (git, bash, starship, helix, ssh, nixvim, fastfetch, btop dotfile). Imported by both modes. **Zero GUI assumptions.** |
| `home/default.nix` | NixOS entry = `common.nix` + GUI terminals (alacritty/ghostty/fuzzel) + GUI terminal dotfiles (kitty/wezterm). |
| `home/standalone-linux.nix` | Non-NixOS Linux entry = `common.nix` + `packages/cli-dev.nix`. Platform-conditional via `stdenv.isLinux`. Zero GUI. |
| `home/standalone-darwin.nix` | macOS entry = `common.nix` + `packages/cli-dev.nix`. Platform-conditional via `stdenv.isDarwin`. Zero GUI. |
| `home/nixvim.nix`, `home/fastfetch.nix` | Split sub-configs imported by `common.nix`. |

GUI HM config stays in `home/default.nix` only — **never** put GUI modules in `common.nix` (breaks WSL/macOS).

`flake.nix` wires it: NixOS mode sets `home-manager.users.xuqihao = import ./home/default.nix`; standalone mode uses `mkStandaloneHome` with platform-specific `standalone-{linux,darwin}.nix`. `home.username`/`homeDirectory`/`stateVersion` are injected by the flake for standalone mode.

## Directory structure

```
flake.nix                  # Dual-mode outputs; forAllSystems helper; pkgs-stable/-master per-system
configuration.nix          # NixOS system-level (boot, GDM, pipewire, user, base packages)
hardware-configuration.nix # HARDWARE-SPECIFIC — gitignored, never commit
modules/                   # AUTO-LOADED into nixosConfigurations.nixos (every *.nix)
home/                      # Home Manager config (NixOS + standalone)
packages/cli-dev.nix       # Shared CLI tool list (pure function) — see architecture above
bootstrap/linux.sh         # One-shot installer for fresh Linux/WSL
dotfiles/                  # Raw config files, referenced via ../dotfiles from home/ and modules/
docs/superpowers/          # Planning/spec docs (design decisions of record)
```

## Modules (auto-loaded, no manual imports)

`flake.nix`'s `generatedModules` scans `modules/*.nix` and loads **all** of them into the NixOS config. Adding a `.nix` file to `modules/` is enough; removing/renaming one drops it from the build.

Module function signatures vary — **only declare the params you actually use** (Nix will error on undeclared args). Examples in-tree:
- `{ config, pkgs, pkgs-stable, pkgs-master, inputs, lib, ... }` — `programs.nix` (needs everything)
- `{ config, pkgs, lib, ... }` — `fix-network.nix` (no packages)

Match the channel to the param you reference: `pkgs-stable` for stable, `pkgs-master` for master, `pkgs` (unstable) for everything else.

Key modules:
- `programs.nix` — giant GUI + CLI app list. Ends with `++ (import ../packages/cli-dev.nix {...})`. Platform-conditional packages use `stdenv.isLinux` guards. Also defines a **wechat overlay**.
- `niri.nix` — Niri (primary) + Hyprland + Sway fallbacks; `dms-shell` enabled as the shell.
- `agents.nix` — `hermes-agent` service + AI tools (cursor, claude-code, codex, opencode…). See "Secrets" below.
- `virtualization.nix` — Docker **and** Podman both enabled; don't point both at the same containers.

## Three nixpkgs channels

- `nixpkgs` (unstable) → `pkgs`
- `nixpkgs-stable` (nixos-26.05) → `pkgs-stable`
- `nixpkgs-master` → `pkgs-master` (wired into `specialArgs`; use sparingly)

All three are instantiated per-system in `flake.nix` (`pkgsFor`) and passed via `specialArgs` / `extraSpecialArgs`. Convention: heavy/stability-sensitive packages (editors, office, toolchains) on `pkgs-stable.`; bleeding-edge stuff on `pkgs`.

```nix
environment.systemPackages = with pkgs; [
  vscode                 # unstable
  pkgs-stable.libreoffice
  pkgs-stable.neovim
];
```

## Flake inputs (actual)

Active: `home-manager` (master), `nixvim` (nixos-26.05), `chaotic` (chaotic-cx/nyx), `hermes-agent`.

**The `noctalia`, `dms`, `quickshell`, `zen-browser` inputs are commented out in `flake.nix`.** But `modules/niri.nix` still references the *packages* `noctalia-shell`, `dms-shell`, `quickshell`, `dsearch` — these come from **`chaotic`** (chaotic-cx/nyx), not from the commented flake inputs. Don't "fix" the missing inputs; don't reference `inputs.noctalia`/`inputs.dms`/`inputs.quickshell` — they don't exist.

Access flake packages in modules that declare `inputs`:
```nix
inputs.nixvim.homeModules.nixvim   # used in home/common.nix
```

## Secrets

`modules/agents.nix` enables `services.hermes-agent` with `environmentFiles = [ "/etc/hermes/env" ];`. That file holds API keys (DeepSeek etc.) and is **not** in the repo — it must exist on the target machine or the service won't start with valid creds. `systemd.tmpfiles.rules` creates `/etc/hermes` (0750 root:hermes); `xuqihao` is added to the `hermes` group for shared-state access.

## Handling EOL / insecure packages

Electron EOL errors (e.g. `Package 'electron-38.8.4' is EOL`) are permitted in **two** places — update **both** when adding a new one:
- `flake.nix` — inside `pkgsFor` / `mkStandaloneHome` (`config.permittedInsecurePackages`)
- `configuration.nix` — `nixpkgs.config.permittedInsecurePackages`

```nix
config.permittedInsecurePackages = [
  "electron-38.8.4"
  "electron-XX.X.X"   # add here, in BOTH files
];
```

## buildEnv conflict gotchas (in `packages/cli-dev.nix`)

Hard-won — read the header comments there before editing that file:
- **Never put both `gcc` and `clang` in a Home Manager `home.packages`**: both wrappers provide `bin/ld` → buildEnv conflict → build fails. On NixOS system-level (`environment.systemPackages`) they coexist fine; in user-level HM they don't. Need clang on a non-NixOS box → use the native package manager.
- **Never put bare `python3` alongside `python3.withPackages (...)`**: buildEnv conflict. Use only the `withPackages` form.
- **Never have two separate `python3.withPackages (...)` calls in the same HM `home.packages`**: both produce python3-env derivations that collide on `bin/idle3` etc. in HM's buildEnv. Merge all Python packages into a single `withPackages` call, using `stdenv.isLinux` / `stdenv.isDarwin` guards for platform-specific packages.

## Style

- **2-space** indentation, no formatter configured — maintain by hand.
- Function headers use ellipsis: `{ config, pkgs, pkgs-stable, ... }:` (only list what you use).
- Numbered section dividers: `# --- 1. Section ---`.
- `with pkgs; [ ... ]` for package lists; prefix stable/master explicitly.
- Mixed English/Chinese comments are normal. Prefer commenting-out over deleting.
- No trailing comma on the last attribute.

## Quick rules

- `hardware-configuration.nix` is **gitignored** — never stage it.
- Adding a module file to `modules/` auto-activates it; no import wiring.
- GUI HM modules → `home/default.nix` only; CLI → `home/common.nix` (needs config) or `packages/cli-dev.nix` (bare tool); Linux-only/Darwin-only packages use `lib.optionals stdenv.isLinux` / `stdenv.isDarwin` inside `cli-dev.nix`.
- Don't uncomment the `noctalia`/`dms`/`quickshell` inputs — those packages are provided by `chaotic`.
- Adding an EOL package → update `permittedInsecurePackages` in **both** `flake.nix` and `configuration.nix`.
