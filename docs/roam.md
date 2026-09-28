# roam 与切换体系（机制细节）

规则摘要（该做什么）在 [`AGENTS.md`](../AGENTS.md)「Build & activate commands」与「NixOS-WSL」；本文承载机制与原因——各部件如何运作、为什么这样设计。内容系 2026-09-28 从 AGENTS.md 的长段拆出（拆分记录见 [`VALIDATION.md`](VALIDATION.md)），措辞以搬运为主。

## 打包与安装位

A repo-owned unified CLI `roam` is the single switch/maintenance entry point: the script is `packages/roam.sh` (macOS-Bash-3.2 compatible), packaged by `packages/roam.nix` as a `symlinkJoin` of a `writeShellApplication` `bin/roam` (build-time `bash -n` + shellcheck gate) and a bash-completion file (`packages/roam-completion.bash` → `share/bash-completion/completions/roam`: subcommands, `check` targets, `update` input names read live from `flake.lock`, `rollback` generation ids + flags, `gc` flags; the completion file bypasses the writeShellApplication gate — it is shellchecked by the flake `checks` gate instead, see the tests section below) and shipped through the shared `cli-dev.nix` list, so all four install sites get `bin/roam` plus its completion.

It carries no `runtimeInputs` — zero closure additions; missing tools are detected per subcommand with a pointer to where they come from (nh: the shared `cli-dev.nix` list on both fronts; home-manager: the bootstrap-installed profile entry, still required for generation enumeration).

## 宿主探测与用户守卫

It reuses `bootstrap/bootstrap.sh`'s host-detection convention (`/etc/NIXOS` present → NixOS, absent → standalone — deliberate duplication like the bootstrap entries). On standalone, `roam switch` applies the arch-named output selection plus the `meta.json` user guard (still refusing cleanly when the login user differs). Repo-touching subcommands require running from a checkout: the relative flake path resolves against the current working directory, and nh's `--hostname` defaults to the hostname which this repo's convention keeps equal to the output attribute (`.#wsl` on WSL, `.#nixos` on the desktop, and any scaffolded host follows directory name = hostname = output name).

On NixOS, `roam switch` additionally **preflights that convention** before dispatching to nh (`nixos_preflight`): one evaluation of `.#nixosConfigurations.<short-hostname>.config.networking.hostName` must exist and equal the short hostname, otherwise a clean error naming the convention — the raw nix attribute-missing error is opaque. `flake.nix`'s `(hostnameGuard "<attr>")` assertion enforces the same invariant via the NixOS `assertions` mechanism: `lib.asserts.checkAssertWarn` **throws at toplevel evaluation**, so any `nix eval` of the drvPath (CI layer 1 included), build or switch fails with the convention message (negative-tested 2026-09-28 on a /tmp copy with a mismatched hostName). The preflight's value over the assertion: it fires before the heavy toplevel evaluation and its error names the fix; the assertion additionally covers manual `nixos-rebuild` paths. The scaffold-printed output blocks in `bootstrap/nixos.sh` carry the guard, so new hosts inherit both.

## nh 双侧后端

Switching goes through nh on **both** fronts (since 2026-09-28; the standalone side previously called `home-manager switch` directly): `nh os switch --diff always .` on NixOS, `nh home switch --diff always --configuration <system> .` on standalone. nh ships via the shared `packages/cli-dev.nix` list to all four install sites, and the former `programs.nh.enable` in `profiles/nixos-base.nix` was retired in favor of that single source (the module did nothing beyond installing the package; still deliberately no `programs.nh.flake`, which would hardcode a checkout path — `roam switch` passes the cwd-relative `.` instead — and no `nh clean`, GC stays with `roam gc`).

nh handles privilege elevation itself (no `sudo` prefix in the command) and prints a dix package diff between generations after each switch (nh 4.x's diff engine; older nh used nvd).

nh home semantics (read against nh 4.4.2 upstream source): nh home builds the `activationPackage` itself and runs its `activate` script (it does **not** exec the home-manager CLI), so generations are registered identically and `roam status`/`rollback`/`doctor` (which enumerate via `home-manager generations`) are unaffected; `home-manager switch --flake .#<system>` remains a working manual fallback (it is the bootstrap path) and its CLI stays installed for that enumeration. nh home shows no HM news and hides activation logs by default (add `--show-activation-logs` when debugging). nh 4.4.2 parses a bare `.#attr` installable as a `packages.<system>.<attr>` shorthand instead of a `homeConfigurations` name — hence the explicit `--configuration` form (upstream master has reworked this; re-check after nixpkgs bumps nh).

## 世代、漂移与回滚

`roam status` answers "should I switch?" by comparing the checkout's eval'd outPath (`activationPackage`/`toplevel`) against the running generation — the `(current)` home-manager generation on standalone, `/run/current-system` on NixOS — with three verdicts: 一致 / 已回滚或检出已回退 (checkout matches some historical generation) / 漂移. Note the standalone verdict must compare against *any* historical generation, not just the latest: rollback's `activate` re-registers old content under a **new** generation id (live-discovered 2026-09-28).

`roam rollback [N|--list]` re-activates an older generation via `<gen>/activate` on standalone (y/N confirm, `--yes` skips; the default target skips same-path duplicates for the same re-registration reason) and `sudo nixos-rebuild --rollback`/`--switch-generation N` on NixOS (nh has no rollback entry point). On NixOS the generation ids are enumerated by globbing `/nix/var/nix/profiles/system-*-link` directly — `nix-env --list-generations` needs the profile lock and silently lists nothing as non-root (`system.lock` permission denied, wsl live-finding 2026-09-28); the profiles directory and its links are world-readable, and link mtimes match nix-env's dates.

`roam switch`/`roam rollback` tee full logs and `roam doctor` writes its report under `~/.local/state/nix-roam/` (the same state dir the bootstrap chains tee into).

## 子命令语义速查

- `roam doctor` runs read-only health checks (user guard, `/nix` free space, generation count + oldest, substituter reachability from `meta.json` via curl, drift, failed systemd units on NixOS), logs to the state dir and exits 1 only on ✗.
- `roam gc [flags]` is the on-demand garbage collector, folded in from the former `bootstrap/gc.sh` on 2026-09-28 (file deleted): user generations first, then system via sudo (`--system`, automatic on NixOS); `--older-than Nd` (default 14d), `--all`, `--dry-run` (print only). A machine operation — no checkout required. It does not refresh boot menus and does not touch the automatic GC configured on NixOS hosts.
- `roam check [--build] [target...]` reproduces CI's two layers locally — `nix eval --raw` of the host target's drvPath by default, `nix build --no-link` with `--build` — with explicit targets `nixos`/`wsl`/`x86_64-linux`/`aarch64-linux`/`aarch64-darwin` for cross-checking foreign outputs (cross-arch stays eval-only; builds need real hardware). Multiple targets (since 2026-09-29) run in input order, deduplicated, and the loop finishes every target before exiting — rc aggregates (`1` if any failed) so a pre-push check sees all breakages, not the first; targets are validated at parse time. The opt-in `.githooks/pre-push` hook (enable once with `git config core.hooksPath .githooks`) is one `roam check` invocation over all five outputs — the local front-run of CI layer 1; bypass once with `git push --no-verify`.
- `roam update [input...|--all]` lists the inputs locked in `flake.lock` (jq) for an interactive pick — Enter/EOF means all (default), numbers and names mix freely — while explicit input names or `--all` skip the prompt and update only the chosen inputs via `nix flake update <input>...`; it prints the `flake.lock` diff but never commits or switches.
- `roam info` prints the host detection read-only.

## 补全机制

The completion is lazy-loaded by bash-completion (≥2.12) from `$XDG_DATA_DIRS`'s `bash-completion/completions/` — HM injects `~/.nix-profile/share` into `XDG_DATA_DIRS` on standalone and NixOS links `/share/bash-completion` into the system profile by default (`environment.pathsToLink`), so both fronts need no extra wiring. The subcommand/flag lists are kept in sync with `packages/roam.sh`'s dispatch and the `gc` flags by hand (see the completion file's header).

## NixOS-WSL 切换可靠性（stc exit 4 的两个来源）

`hosts/wsl/default.nix` masks **both** `getty@tty1.service` and `autovt@tty1.service` (`systemd.units.<name>.enable = false` → `/dev/null` symlink): WSL has no real tty1, so a getty template instance pulled up during a switch is SIGHUP-killed (start-limit-hit) and makes switch-to-configuration exit 4. The two names are instances of the same template but distinct units — masking one does not cover the other (the 2026-09-18 mask of `getty@tty1` alone did not prevent the 2026-09-26 failure of `autovt@tty1`). This is load-bearing for `roam switch` on NixOS: `nh` activates via stc **before** setting the system profile, so any stc exit 4 aborts nh before the generation is created — and NixOS-WSL boots systemd from the persistent profile path, so such switches are ephemeral (lost at the next `wsl --shutdown`). `nixos-rebuild` sets the profile before running stc and lands generations despite exit 4; after any failed switch, recover with `sudo nixos-rebuild switch --flake .#wsl`.

`hosts/wsl/default.nix` also sets `users.users.<username>.linger = true` — a second stc-exit-4 source with the same nh consequence. WSL boots without a login session, so the user manager (`user@1000.service`) would not start and `/run/user/1000/bus` would be missing; stc's user-unit reload then fails with exit 4 even with zero failed units. Linger (the declarative equivalent of `loginctl enable-linger`) keeps the user manager running from boot, making cold-start `roam switch` reliable (verified across `wsl --shutdown`, 2026-09-26). Desktop hosts don't need it — display-manager login starts the user manager — which is why the option lives in `hosts/wsl` and not in `profiles/nixos-base.nix`.

## 测试与关卡

The unit tests (`tests/roam-functions.sh`) source `packages/roam.sh` directly: its dispatch section is guarded by `${BASH_SOURCE[0]} = $0`, so sourcing loads the functions without executing (keep that guard when editing); `system_generation_ids` is redirectable via `ROAM_SYSTEM_PROFILES_DIR` for stubbing; `home-manager` is stubbed by a PATH-injected fake; `standalone_target` is exercised by re-sourcing inside a stubbed `uname` (the `kernel` variable is captured at source time). The completion harness (`tests/completion-harness.sh`) drives `_roam` with simulated COMP_WORDS/COMP_CWORD — the same code path as a real TAB. Rollback generation numbers depend on live host state, so the harness asserts flags only; `update` input names read the checkout's real `flake.lock` with membership assertions.

Two sandbox findings from wiring the tests into flake `checks` (2026-09-28, both fixed in code comments where they apply):

1. The `bash` on a build sandbox's PATH is stdenv's minimal build — no progcomp, so `compgen` is unavailable (the same locked rev's `bash-interactive` outside the sandbox is fine). Checks that exercise completion builtins must add `bashInteractive` to `nativeBuildInputs`.
2. Build sandboxes have no `/usr/bin/env` — a stub script's shebang must be generated from `$BASH` (the running shell's absolute path), not the customary `#!/usr/bin/env bash`.
