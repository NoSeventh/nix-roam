# roam 与切换体系（机制细节）

规则摘要（该做什么）在 [`AGENTS.md`](../AGENTS.md)「Build & activate commands」与「NixOS-WSL」；本文承载机制与原因——各部件如何运作、为什么这样设计。内容系 2026-09-28 从 AGENTS.md 的长段拆出（拆分记录见 [`VALIDATION.md`](VALIDATION.md)），措辞以搬运为主。

## 打包与安装位

`packages/roam.sh` 是保持 sourceable 的分发入口，命令实现位于
`packages/roam/`：core、generations、switch、rollback、gc、modules、mnt、check、inputs。
直接运行从入口旁加载命令库；Nix 打包固定 `ROAM_LIB_DIR` 到库的 store 路径，
因此安装后不依赖 checkout 中的脚本路径。`writeShellApplication` 检查入口，
flake 的 shellcheck-scripts 检查每个命令文件。补全仍随 symlinkJoin 成对安装。

四个安装点通过 cli-dev 共享 roam、nh 和 jq。没有 runtimeInputs；需要 JSON 的
命令检查 jq 可用性并明确报错。home-manager CLI 仍由 bootstrap 安装，负责世代
枚举。源码和已安装入口都保持 macOS Bash 3.2 兼容。

## 宿主探测与用户守卫

It reuses `bootstrap/bootstrap.sh`'s host-detection convention (`/etc/NIXOS` present → NixOS, absent → standalone — deliberate duplication like the bootstrap entries). On standalone, `roam switch` applies the arch-named output selection plus the `meta.json` user guard (still refusing cleanly when the login user differs). Repo-touching subcommands require running from a checkout: the relative flake path resolves against the current working directory, and nh's `--hostname` defaults to the hostname which this repo's convention keeps equal to the output attribute (`.#wsl` on WSL, `.#nixos` on the desktop, and any scaffolded host follows directory name = hostname = output name).

On NixOS, `roam switch` additionally **preflights that convention** before dispatching to nh (`nixos_preflight`): one evaluation of `path:./.#nixosConfigurations.<short-hostname>.config.networking.hostName` must exist and equal the short hostname, otherwise a clean error naming the convention — the raw nix attribute-missing error is opaque. `flake.nix`'s `(hostnameGuard "<attr>")` assertion enforces the same invariant via the NixOS `assertions` mechanism: `lib.asserts.checkAssertWarn` **throws at toplevel evaluation**, so any `nix eval` of the drvPath (CI layer 1 included), build or switch fails with the convention message (negative-tested 2026-09-28 on a /tmp copy with a mismatched hostName). The preflight's value over the assertion: it fires before the heavy toplevel evaluation and its error names the fix; the assertion additionally covers manual `nixos-rebuild` paths. The scaffold-printed output blocks in `bootstrap/nixos.sh` carry the guard, so new hosts inherit both.

## nh 双侧后端

Switching goes through nh on **both** fronts (since 2026-09-28; the standalone side previously called `home-manager switch` directly): `nh os switch --diff always -H <host> path:./.` on NixOS, `nh home switch --diff always --configuration <system> path:./.` on standalone. Since 2026-10-11 every roam-side nix/nh invocation uses **`path:./.` flake refs** — the path view copies the whole checkout (gitignore not consulted), so the machine-local module selection `local.<hostKey>.json` enters evaluation; bare `.#` (git view) can't see gitignored files and yields the tracked defaults (dual-view semantics: [`modules.md`](modules.md)). `-H` is passed explicitly on the os side because nh's default hostname inference keys off the flake-ref's directory name, which doesn't apply to `path:` refs. nh ships via the shared `packages/cli-dev.nix` list to all four install sites, and the former `programs.nh.enable` in `profiles/nixos-base.nix` was retired in favor of that single source (the module did nothing beyond installing the package; still deliberately no `programs.nh.flake`, which would hardcode a checkout path — `roam switch` passes the cwd-relative `path:./.` instead — and no `nh clean`, GC stays with `roam gc`).

nh handles privilege elevation itself (no `sudo` prefix in the command) and prints a dix package diff between generations after each switch (nh 4.x's diff engine; older nh used nvd).

nh home semantics (read against nh 4.4.2 upstream source): nh home builds the `activationPackage` itself and runs its `activate` script (it does **not** exec the home-manager CLI), so generations are registered identically and `roam status`/`rollback`/`doctor` (which enumerate via `home-manager generations`) are unaffected; `home-manager switch --flake path:./.#<system>` remains a working manual fallback (also the local bootstrap path), preserving the same local selection, and its CLI stays installed for that enumeration. nh home shows no HM news and hides activation logs by default (add `--show-activation-logs` when debugging). nh 4.4.2 parses a bare `.#attr` installable as a `packages.<system>.<attr>` shorthand instead of a `homeConfigurations` name — hence the explicit `--configuration` form (upstream master has reworked this; re-check after nixpkgs bumps nh).

## 世代、漂移与回滚

`roam status` answers "should I switch?" by comparing the checkout's eval'd outPath (`activationPackage`/`toplevel`) against the running generation — the `(current)` home-manager generation on standalone, `/run/current-system` on NixOS — with three verdicts: 一致 / 已回滚或检出已回退 (checkout matches some historical generation) / 漂移. Note the standalone verdict must compare against *any* historical generation, not just the latest: rollback's `activate` re-registers old content under a **new** generation id (live-discovered 2026-09-28).

`roam rollback [N|--list]` re-activates an older generation via `<gen>/activate` on standalone (y/N confirm, `--yes` skips; the default target skips same-path duplicates for the same re-registration reason) and `sudo nixos-rebuild --rollback`/`--switch-generation N` on NixOS (nh has no rollback entry point). On NixOS the generation ids are enumerated by globbing `/nix/var/nix/profiles/system-*-link` directly — `nix-env --list-generations` needs the profile lock and silently lists nothing as non-root (`system.lock` permission denied, wsl live-finding 2026-09-28); the profiles directory and its links are world-readable, and link mtimes match nix-env's dates.

`roam switch`/`roam rollback` tee full logs and `roam doctor` writes its report under `~/.local/state/nix-roam/` (the same state dir the bootstrap chains tee into).

## 子命令语义速查

- `roam doctor` runs read-only health checks (user guard, `/nix` free space, generation count + oldest, substituter reachability from `meta.json` via curl, drift, failed systemd units on NixOS), logs to the state dir and exits 1 only on ✗.
- `roam gc [flags]` is the on-demand garbage collector, folded in from the former `bootstrap/gc.sh` on 2026-09-28 (file deleted): user generations first, then system via sudo (`--system`, automatic on NixOS); `--older-than Nd` (default 14d), `--all`, `--dry-run` (print only). A machine operation — no checkout required. It does not refresh boot menus and does not touch the automatic GC configured on NixOS hosts.
- `roam check [--build] [target...]` evaluates drvPaths by default and builds with `nix build --no-link` under `--build`. Targets are explicit: `nixos`/`wsl`/`x86_64-linux`/`aarch64-linux`/`aarch64-darwin`; the default is the current host. Every check uses `path:./.` (current checkout plus local selections). Repeated targets are deduplicated; evaluations run concurrently and report in input order, finishing all targets before returning `1` if any failed. Builds stay sequential to avoid multiplying builder memory/CPU usage. Cross-architecture validation stays eval-only without native hardware or a builder.
- `roam update [input...|--all]` lists the inputs locked in `flake.lock` (jq) for an interactive pick — Enter/EOF means all (default), numbers and names mix freely — while explicit input names or `--all` skip the prompt and update only the chosen inputs via `nix flake update <input>...`; it prints the `flake.lock` diff but never commits or switches.
- `roam flake [-a|--all]` reads flake.lock locally with jq, follows its root-to-node mappings, and prints names/revisions/dates/refs/sources. `--all` includes transitive nodes. It does not evaluate or fetch inputs; malformed/unsupported lock structures fail clearly.
- `roam module init|list|enable|disable [names...|--host K]` (added 2026-10-11) maintains the machine-local module selection `local.<hostKey>.json` — the bash front end of `lib/selection.nix` (mechanism: [`modules.md`](modules.md)). `init` seeds from the current effective selection (one light eval of `config.roam.selectedModules`), so a fresh init changes nothing; `list` prints the registry with per-machine on/off; `enable`/`disable` validate against the registry first (unknown name / front-not-applicable / darwin-non-whitelisted die before any file is touched — mirroring the Nix-side throws), seed from the effective selection when no local file exists, then rewrite the file (idempotent; disable of a not-enabled tier is a no-op note) and print the delta with `roam check <K>`/`roam switch` hints. The registry and selection files are parsed structurally with jq, independent of indentation/key order; `tests/module-registry.sh` checks output fields and file applicability; the selection file is strict JSON (no trailing comma — `fromJSON` rejects it) with a `host` self-check field. hostKey: hostname on NixOS, output name on standalone.
- `roam mnt [start|stop|status]` is the mnt mount entry and works outside the checkout. No argument means `status`; it reports state without writing logs or triggering Linux automounts. `start`/`stop` are logged under `~/.local/state/nix-roam/`. NixOS uses sudo to start/stop system-level mount units named with `systemd-escape --path`; `start` registers the trigger and clears an earlier mount failure for retry. Standalone Linux starts direct background SSHFS under a lock and checks for an actual mount, preserving early SSHFS failure codes instead of reporting success after a fixed sleep. macOS writes an autofs map under `~/.config/nix-roam/auto_sshfs`; after enabling `mnt` and applying it, run `~/.config/nix-roam/enable-autofs-mnt` once to register the map with `/etc/auto_master`, then access to `~/mnt/juno` is lazy. The helper intentionally uses sudo explicitly rather than requesting root during Home Manager activation.
- `roam info` prints the host detection read-only.

## mnt Linux 自动挂载故障与排查

### 当前实现

[`modules/mnt/nixos.nix`](../modules/mnt/nixos.nix) 定义系统级 mount/automount：
开机只启动 automount，访问 `~/mnt/juno` 才建立 SSHFS，空闲五分钟后卸载。
普通用户 manager 无权创建 autofs，不能改回 `systemd.user`。

专用的 `mount.fuse.roam-sshfs` helper 通过 `system.fsPackages` 注册；系统负责
FUSE 挂载，SSH 子进程通过 `runuser` 切换到配置中的登录用户，读取该用户的 SSH
配置、私钥和 known_hosts，不使用 root 的 SSH 身份。UID/GID 从运行时账户数据库
解析；`uid/gid + allow_other + default_permissions + umask=0077` 允许登录用户
访问 root 建立的挂载，同时保留本地仅所有者可访问的权限。SSH 使用
`BatchMode=yes`、`StrictHostKeyChecking=yes` 和十秒连接超时；秘密不进入 store。

[`packages/roam/mnt.sh`](../packages/roam/mnt.sh) 按挂载路径转义单元名，并操作
系统级管理器。Linux 状态检查只读取挂载表中的 `fuse.sshfs`，使用
`findmnt --nocanonicalize` 避免路径解析触发 autofs。状态可区分 `mounted`、
`automount ready ... (not mounted)`、`not mounted`；若 mount 单元失败则返回非零并
提示 `journalctl`，不会用仍然 active 的 automount 掩盖 SSH 错误。

[`home/mnt-linux.nix`](../home/mnt-linux.nix) 不再生成用户 mount/automount。
standalone Linux 的交互 Bash 调用 `roam mnt start`，有无 user bus 均走直接 SSHFS；
锁内等待实际挂载成功，失败返回非零，日志写入 `~/.local/state/nix-roam/mnt.log`。
宿主须提供可用的 FUSE 设备与非 root 挂载工具。该前端不提供按目录访问触发或
空闲卸载；原生系统级 automount 由宿主 OS 管理。

### SSH 前置条件与诊断

新机器先运行 `ssh xuqihao@lxlogin.ihep.ac.cn`，核对主机指纹。若非交互认证
失败，运行 `ssh-copy-id -i ~/.ssh/id_rsa.pub xuqihao@lxlogin.ihep.ac.cn` 完成
公钥授权（使用其他密钥时替换路径），再检查 BatchMode。仅能输入密码登录还不足以
支持后台挂载；加密私钥也需要系统挂载进程可用的非交互认证方式。

NixOS 排查命令（`status`/`findmnt` 不触发连接，最后的 `ls` 才访问远端）：

```bash
unit="$(systemd-escape --path "$HOME/mnt/juno")"
systemctl --system status "$unit.automount" "$unit.mount"
journalctl -b -u "$unit.automount" -u "$unit.mount"
findmnt -rn --nocanonicalize --mountpoint "$HOME/mnt/juno"
roam mnt status
ssh-keygen -F lxlogin.ihep.ac.cn
ssh -o BatchMode=yes -o ConnectTimeout=8 xuqihao@lxlogin.ihep.ac.cn true
roam mnt start
ls "$HOME/mnt/juno"
```

旧实现的普通用户 automount 权限错误、CLI 名称不一致和 SSH 首次认证问题，以及
后续修复的实测边界，见 [`VALIDATION.md`](VALIDATION.md)。

## pre-push：验证推送快照

启用：`git config core.hooksPath .githooks`；单次绕过：`git push --no-verify`。
钩子完整读取 stdin 的 `<local_ref> <local_sha> <remote_ref> <remote_sha>` 协议，
按每个 ref 的端点差异门控。`EVAL_SKIP_RE` 是已知非输入黑名单
（docs/tests/bootstrap/.github/.githooks 与根 README/AGENTS/LICENSE/.gitignore）；
清单外路径、新分支、远端 SHA 缺失均检查，删除 ref、空差异和纯非输入增量放行。
`gate_needed` 的 here-string 避免 `printf | grep -q` 的 SIGPIPE 漏放行；空差异
单独排除。`tests/prepush-gate.sh` 审计黑名单与 Nix 引用不交叉。

需要检查的 local SHA 经 `^{commit}` 解析（含 annotated tag peel）并去重。
每个不同 commit 使用 `git+file://<checkout>?rev=<SHA>&allRefs=1` 锁定源，
直接并行求值默认五输出的 drvPath；`allRefs` 支持非 HEAD 分支/标签。
不执行工作树或待推送版本里的 roam 脚本，不用当前 HEAD 替代协议里的 SHA。
多个 commit 依次检查，全部检查后汇总失败；只求值，不构建或激活。

这层与 CI 默认集语义一致：未提交修改和 ignored `local.*.json` 不进快照，
不能用本地修复或关闭模块掩盖待推送提交的错误。本机选配仍由 `roam check`
单独核对。2026-10-13 前的钩子检查当前 `path:./.` 工作树，历史记录中的
“本机视图验证”不再描述当前行为。

## 补全机制

The completion is lazy-loaded by bash-completion (≥2.12) from `$XDG_DATA_DIRS`'s `bash-completion/completions/` — HM injects `~/.nix-profile/share` into `XDG_DATA_DIRS` on standalone and NixOS links `/share/bash-completion` into the system profile by default (`environment.pathsToLink`), so both fronts need no extra wiring. The subcommand/flag lists are kept in sync with `packages/roam.sh`'s dispatch and the `gc` flags by hand (see the completion file's header).

## NixOS-WSL 切换可靠性（stc exit 4 的两个来源）

`hosts/wsl/default.nix` masks **both** `getty@tty1.service` and `autovt@tty1.service` (`systemd.units.<name>.enable = false` → `/dev/null` symlink): WSL has no real tty1, so a getty template instance pulled up during a switch is SIGHUP-killed (start-limit-hit) and makes switch-to-configuration exit 4. The two names are instances of the same template but distinct units — masking one does not cover the other (the 2026-09-18 mask of `getty@tty1` alone did not prevent the 2026-09-26 failure of `autovt@tty1`). This is load-bearing for `roam switch` on NixOS: `nh` activates via stc **before** setting the system profile, so any stc exit 4 aborts nh before the generation is created — and NixOS-WSL boots systemd from the persistent profile path, so such switches are ephemeral (lost at the next `wsl --shutdown`). `nixos-rebuild` sets the profile before running stc and lands generations despite exit 4; after any failed switch, recover with `sudo nixos-rebuild switch --flake path:./.#wsl`, keeping `local.wsl.json` in evaluation.

`hosts/wsl/default.nix` also sets `users.users.<username>.linger = true` — a second stc-exit-4 source with the same nh consequence. WSL boots without a login session, so the user manager (`user@1000.service`) would not start and `/run/user/1000/bus` would be missing; stc's user-unit reload then fails with exit 4 even with zero failed units. Linger (the declarative equivalent of `loginctl enable-linger`) keeps the user manager running from boot, making cold-start `roam switch` reliable (verified across `wsl --shutdown`, 2026-09-26). Desktop hosts don't need it — display-manager login starts the user manager — which is why the option lives in `hosts/wsl` and not in `profiles/nixos-base.nix`.

## 测试与关卡

The unit tests (`tests/roam-functions.sh`) source `packages/roam.sh` directly: its dispatch section is guarded by `${BASH_SOURCE[0]} = $0`, so sourcing loads the functions without executing (keep that guard when editing); `system_generation_ids` is redirectable via `ROAM_SYSTEM_PROFILES_DIR` for stubbing; `home-manager` is stubbed by a PATH-injected fake; `standalone_target` is exercised by re-sourcing inside a stubbed `uname` (the `kernel` variable is captured at source time). The completion harness (`tests/completion-harness.sh`) drives `_roam` with simulated COMP_WORDS/COMP_CWORD — the same code path as a real TAB. Rollback generation numbers depend on live host state, so the harness asserts flags only; `update` input names read the checkout's real `flake.lock` with membership assertions. The pre-push diff gate has its own suite (`tests/prepush-gate.sh`): it sources `.githooks/pre-push` (same BASH_SOURCE guard pattern, so keep that guard when editing the hook) and drives `gate_needed` with a stubbed `git` function over simulated pre-push stdin lines — the assertions pin the gate's *direction* (eval-input hits and conservative fallbacks intercept; docs-only deltas, deletion pushes and empty diffs release), because a silently inverted or over-eager gate would either block every push or stop guarding at all.

Two sandbox findings from wiring the tests into flake `checks` (2026-09-28, both fixed in code comments where they apply):

`tests/prepush-snapshots.sh` 用临时真 Git 仓库、多提交和 annotated tag 驱动
钩子主入口，验证工作树/索引/local 隔离、多 ref 去重与失败汇总、缺 SHA 和
跳过路径。默认用 nix 桩；本机可运行 `bash tests/prepush-snapshots.sh --real-nix`
用无外部输入的最小 flake 验证同一链路。沙箱 tests 环境同时提供 git。

1. The `bash` on a build sandbox's PATH is stdenv's minimal build — no progcomp, so `compgen` is unavailable (the same locked rev's `bash-interactive` outside the sandbox is fine). Checks that exercise completion builtins must add `bashInteractive` to `nativeBuildInputs`.
2. Build sandboxes have no `/usr/bin/env` — a stub script's shebang must be generated from `$BASH` (the running shell's absolute path), not the customary `#!/usr/bin/env bash`.
