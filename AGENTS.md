# AGENTS.md

## Scope and documentation

One flake supports NixOS desktop (`nixosConfigurations.nixos`), NixOS-WSL
(`nixosConfigurations.wsl`), and standalone Home Manager (`homeConfigurations`:
`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`). NixOS outputs are x86_64-linux;
macOS is Apple Silicon only. Select explicit outputs; never use `--impure`,
environment variables, or the evaluation host to choose the evaluation target.

README is usage, AGENTS is standing rules, and `docs/` is mechanism, rationale,
and history. Keep README and these rules aligned with implementation. Dated
verification belongs in [`docs/VALIDATION.md`](docs/VALIDATION.md).

## Detect the host before acting

Inspect `/etc/os-release`, `uname -a`, and whether `/etc/NIXOS` exists before
host-specific diagnosis, edits, builds, or activation. State the detected mode.
Never infer it from the cwd, hostname, flake outputs, `/run/current-system`
alone, or older documentation's wording.

- `/etc/NIXOS` present: NixOS; system settings belong in `hosts/`, `profiles/`,
  or `modules/`. WSL uses `.#wsl`, desktop uses its named NixOS output.
- Absent: standalone Nix on Linux/WSL or macOS; use Home Manager and the matching
  explicit architecture output. Native services remain owned by the host OS.
- Standalone has no root Home Manager profile or `darwinConfigurations`.
  GUI/session dotfiles stay out of `home/common.nix`; Linux application tiers
  are opt-in, while the standalone baseline is CLI-only.

## Build and activate

| Target | Command |
|---|---|
| Auto-detected bootstrap | `bash bootstrap/bootstrap.sh` |
| NixOS desktop | `sudo nixos-rebuild switch --flake path:./.#nixos` |
| NixOS-WSL | `sudo nixos-rebuild switch --flake path:./.#wsl` |
| Live ISO, mounted `/mnt` | `bash bootstrap/nixos.sh install` |
| Adopt existing NixOS | `sudo bash bootstrap/nixos.sh` |
| Fresh standalone Linux/WSL | `bash bootstrap/linux.sh` |
| Fresh Apple Silicon macOS | `bash bootstrap/darwin.sh` |
| Existing standalone Linux | `home-manager switch --flake path:./.#x86_64-linux` (ARM: `aarch64-linux`) |
| Existing standalone macOS | `home-manager switch --flake path:./.#aarch64-darwin` |
| Routine maintenance | `roam switch/status/doctor/rollback/gc/check/update/flake/module/info` |

`roam` is the switch/maintenance entry; do not reintroduce `hms`/`nrs` aliases.
Operational aliases live in `home/common.nix`, Linux-only keys gated with
`lib.optionalAttrs isLinux`. Repo-touching roam commands require the checkout
root; rollback and gc do not. Switching uses nh on both fronts:
`nh os switch --diff always -H <host> path:./.` or
`nh home switch --diff always --configuration <system> path:./.`.
Standalone switching must preserve the `meta.json` login-user guard.
See [`docs/roam.md`](docs/roam.md) for generations, rollback, logs, and WSL recovery.

For a build without activation, use `nix build --no-link` with
`path:./.#nixosConfigurations.<host>.config.system.build.toplevel` or
`path:./.#homeConfigurations.<system>.activationPackage`. Bare `.#` checks
tracked defaults; `path:./.` includes local selections. `nix run` on an
activation package is not a dry build. A WSL build on another distribution does
not verify WSL boot/login. Update inputs with `nix flake update` / `roam update`,
review and commit `flake.lock`, then validate affected targets;
`nix-channel --update` does not update the lock.

## Composition and package ownership

- `hosts/`: machine settings and tracked hardware; `profiles/`: explicit base
  compositions; `modules/desktop/`: desktop base; `modules/<tier>/`: selectable
  tiers; `home/`: user configuration; `packages/`: lists and repo tools.
- Bases use explicit imports. A new base file is inert until imported; never
  scan directories to auto-load modules.
- `packages/cli-dev.nix` is a pure package-list function imported at four sites:
  `profiles/cli.nix`, `modules/desktop/core.nix`, and both standalone entries.
  Bare shared CLI binaries go here; configured CLI tools go in `home/common.nix`.
  Do not duplicate them. Platform packages use `lib.optionals` with
  `stdenv.hostPlatform.isLinux` / `isDarwin`; bubblewrap is Linux-only.
- NixOS installs shared CLI system-wide for sudo visibility. Standalone installs
  it in the user profile; do not assume `sudo -E` overrides native secure_path.
- Each selectable application's common list is `modules/<tier>/packages.nix`.
  Its `home.nix` returns that list; `nixos.nix` installs it and adds system-only
  services/tools. Keep deliberate front differences explicit. Do not introduce
  clang or bare neovim into standalone dev: gcc and nixvim already own the
  conflicting binaries. Keep one Python environment where one is managed.
- `mnt` uses system-level mount/automount on NixOS; ordinary user systemd cannot
  run automounts. Derive unit names from the mount path. Its helper runs SSH as
  the login user and resolves UID/GID at runtime; keys and known_hosts stay in
  that user's home. Standalone Linux uses direct SSHFS with checked startup.
  Status must distinguish autofs from SSHFS without touching the mount path.
- `profiles/nixos-base.nix` owns NixOS-only Node/npm/pnpm, R, and scientific
  Python/PyROOT. Python bindings use the same Python package set; rpy2's wrapper
  sets matching `R_HOME`. Standalone retains uv and project/native runtimes.
  The C++ ROOT application remains in the shared Linux CLI list. Application
  internal interpreters are not project runtimes and must not be removed.
- Desktop base is session + niri + locale-zh + core, imported by
  `profiles/desktop.nix`. Core's direct application choices stay open-source;
  proprietary/experimental additions belong in optional tiers.
- `home/common.nix` is CLI-only. `home/default.nix` owns desktop terminals and
  compositor dotfiles; `home/nixos-cli.nix` is integrated HM for NixOS-WSL.
  Never import standalone Linux into NixOS. Standalone entries retain their
  guarded zsh/fish session loaders without taking over native rc files; Linux
  creates no rc for an unused shell and retains `~/.nix-profile/bin` in PATH.
- `home/nixvim.nix` explicitly imports `home/nixvim/` components. Keep option,
  keymap, plugin, and extra Lua ordering stable when moving configuration.

## Registry and local selection

`modules/registry.json` is the single source for names and `nixos/home/darwin`
flags. Implementations are conventional `modules/<name>/{nixos,home}.nix`;
shared application lists may live beside them. Register new tiers with honest
flags; a `home.nix` with `home:false` is rejected by the test gate.

`lib/selection.nix` consumes JSON with fromJSON; roam uses jq from the shared
CLI list. JSON meaning must not depend on indentation or field order. Unknown
names, inapplicable fronts, Darwin non-whitelisted modules, and mismatched
local `host` fields must fail. `config.roam.selectedModules` is read-only
metadata. Darwin's whitelist is currently empty.

`local.<hostKey>.json` is gitignored; `roam module init/list/enable/disable`
maintains it. Host key is NixOS hostname or standalone output name. A present
file is the complete authoritative selection, replacing the tracked default;
absence uses the explicit default in each host/standalone entry. Defaults are
the 11 open-source tiers for desktop (the unfree android tier is opt-in per
machine) and empty for WSL/standalone. Git evaluation and remote
`git+https` cannot see ignored files. Roam and CI module-matrix use `path:./.`;
CI's default eval and pre-push commit snapshots use Git. Local switch/build
and recovery examples must use `path:./.` to retain selections.
See [`docs/modules.md`](docs/modules.md).

## Host wiring

`flake.nix` wires outputs and passes `inputs`, `username`, `stateVersion`, and
`pkgs-stable` through module arguments. `home.username/homeDirectory/stateVersion`
come from that wiring. Local username and cache metadata are single-sourced in
root `meta.json`; scripts must abort on extraction failure, never fall back to
hardcoded values. Remote SSH identities and Git email remain personal settings
in `home/common.nix` and do not derive from the local username.

`hosts/<host>/default.nix` holds machine settings. Track real generated hardware
files under that directory; do not generate root `hardware-configuration.nix`.
`variables.nix` is a plain attrset passed as `vars` by the flake; consuming
modules declare that argument, never import a host by string path. Standalone
receives no vars. Preserve an adopted system's original stateVersion.

Add a host via `bootstrap/nixos.sh adopt/install --target <host>` or copy
`hosts/_template/`, replace `__HOSTNAME__`, supply hardware/variables, and add
an explicit flake output with `(hostnameGuard "<host>")`. The script prints
output blocks; it never edits the flake. Directory = hostName = output name is
asserted and preflighted. Choose the desktop or CLI composition and matching HM
entry, then build before first switch. `profiles/hardware/` GPU/VM profiles are
inert until explicitly imported; NVIDIA bus IDs come from vars. They are not
covered by ordinary output CI: validate when first adopting them.

NixOS-WSL retains both tty1 getty masks and user linger. All NixOS outputs import
the Hermes module so an enabled agents tier can use its options. After a failed
WSL nh switch, recover with `sudo nixos-rebuild switch --flake path:./.#wsl`.

## Inputs and channels

Unstable is `pkgs`; nixos-26.05 is `pkgs-stable`. `pkgsFor` instantiates both
with shared config; NixOS system unstable has its own config. Heavy/stable tools
normally use `pkgs-stable`, newer tools use `pkgs`. No `pkgs-master` exists.
Nixvim has its own lock input and deliberately does not follow repo nixpkgs.
Inspect both `flake.nix` and `profiles/nixos-base.nix` for insecure exceptions;
update only affected instances with exact approved package/version entries.
Rationale and historical cases: [`docs/modules.md`](docs/modules.md).

The commented noctalia/dms/quickshell/zen-browser inputs must stay commented.
Their shell packages/modules come from nixpkgs unstable; do not reference the
nonexistent inputs or reintroduce removed chaotic/master inputs casually.

## Nix settings, bootstrap, and secrets

- `meta.json` single-sources username, substituters, and the Cachix key. Never
  use CERNET/MirrorZ help/index sites as actual substituters or dead Git mirrors
  as input sources. Cache order/mechanism: [`docs/mirrors.md`](docs/mirrors.md).
- NixOS daemon settings belong in `modules/fix-network.nix`; standalone user
  settings belong in `home/nix-cn.nix`, never imported by common. Set
  `nix.package = pkgs.nix` for HM. Use `mkForce` only on individual settings,
  preserve flakes, connect-timeout=5, and fallback=true. Large buffers,
  auto-optimise-store, and NIXPKGS_ALLOW_UNFREE remain NixOS-specific.
- The Cachix key belongs daemon-side or single-user nix.conf, not standalone
  HM's restricted user setting. Keep Linux/Darwin bootstrap write mechanics
  mirrored: multi-user uses trusted-substituters and extra-trusted-public-keys
  in included `/etc/nix/nix.custom.conf`; never grant blanket trusted-users.
- Bootstrap dispatcher and sub-scripts remain directly runnable, logging to
  the state directory. Preserve backup/symlink guards for existing dotfiles
  and managed nix.conf; routine updates use HM/roam. Keep Linux `run_as_root`
  and `su_root` as top-level multiline bodies (tests extract them).
  Details: [`docs/bootstrap.md`](docs/bootstrap.md).
- Tokens stay outside Git/store in 0600 `~/.config/nix/github-access-tokens.conf`
  with optional !include. Read token input through stdin, never logs. Hermes
  secrets live in `/etc/hermes/env`; `modules/agents/nixos.nix` owns service,
  directory permissions, and the username-derived Hermes group membership.
- npm registry/prefix stay session variables and the npmr alias, not read-only
  managed .npmrc. Global prefix is ~/.npm-global; project overrides require
  --registry or unsetting NPM_CONFIG_REGISTRY. This does not configure sudo npm.
- Automatic NixOS GC is weekly (>2w) plus daily optimise and weekly user-profile
  cleanup. Manual roam gc defaults to 14d, removes rollback availability for
  deleted generations, and does not refresh boot menus. Standalone system/root
  cleanup requires --system; referenced paths remain protected.

## Style, tests, and delivery

- Use the explicit `nixpkgs-fmt` formatter (`nix fmt <edited-files>`); 2-space
  indentation, parameters actually used plus `...`, and numbered sections where
  useful. Mixed English/Chinese comments are fine. Keep useful disabled choices;
  move migration timelines and long historical explanations into docs.
- `packages/roam.sh` loads `packages/roam/*.sh`; its BASH_SOURCE dispatch guard
  and `.githooks/pre-push`'s guard must remain sourceable for tests. Keep Bash
  3.2 compatibility. The package pins its command-library store path; jq and
  other runtime tools come from the install sites, without runtimeInputs.
- `nix flake check` builds selection-metadata, shellcheck-scripts, and roam-unit-tests; every command
  library file is statically checked. Test stubs use $BASH shebangs, and completion
  checks require bashInteractive. Run tests/run-all.sh for local script checks.
- CI evaluates five outputs, builds x86_64 standalone, and runs flake checks.
  The registry-driven module-matrix covers per-tier isolation, all-on WSL,
  Darwin rejection, and all-on x86_64 standalone build. NixOS/ARM/macOS build
  and activation claims must reflect the actual validation performed.
- Opt-in pre-push (`git config core.hooksPath .githooks`) diff-gates concurrent
  default five-output evals of each pushed commit from the stdin protocol.
  Pin `git+file` to that SHA, peel annotated tags, and deduplicate commits;
  never substitute HEAD, the index, working-tree changes, or local selections.
  Check all required snapshots before returning failure. EVAL_SKIP_RE is a blacklist of known non-inputs:
  docs/tests/bootstrap/.github/.githooks and root README/AGENTS/LICENSE/.gitignore.
  Unknown paths require eval; test audits forbid Nix references into skip-listed
  paths except the sanctioned tests check. Bypass once with --no-verify.
- For Nix edits: parse, evaluate affected options/derivations, then build affected
  native targets. Eval is not build; build is not activation. For docs: check
  source consistency, links, stale references, and git diff --check.
- Record each completed change pass with host/distro, eval/build/activation,
  and remaining boundaries in docs/VALIDATION.md. Reliable verified passes are
  committed directly; risky/unverified/pending work stays uncommitted and is
  reported. Do not push automatically.
- Gitee is origin; GitHub is optional github. Inspect remotes before pushing.
  Sync never forces history or deletes remote refs; workflow changes require
  local credentials to both remotes. Keep new URLs on nix-roam; preserve bootstrap
  old-clone recognition. Details: [`.github/SYNC.md`](.github/SYNC.md).
