# 验证记录（Validation boundaries）

按日期记录每次改动实际验证到的边界（新 → 旧）。**状态只反映记录当时**，不代表当前提交已重新构建；具体验证环境（发行版 / 主机）以各条为准。

判断标准与常用手法：

- 对 Nix 改动：解析编辑过的文件 → 求值受影响的选项 / 派生 → 构建对应目标。不把「求值通过」当「构建通过」，不把「构建通过」当「激活通过」，也不把当前主机上找到的命令当作另一目标包内容的证据。
- 「纯重构」用五输出 drvPath 前后对比验证（干净树 vs 干净树）：`nix eval --raw .#<target>.drvPath`。注意 HM 侧 `programs.*` 子选项「显式设置为空值」与「未设置」可能生成不同文本（曾见于 `programs.bash.initExtra`：空串会多出一个换行），布尔注入必须用属性集级 `lib.optionalAttrs` 而非字符串级 `lib.optionalString`。
- 对纯文档改动：检查源一致性、本地链接、被删路径的引用与 `git diff --check`，无需重建或激活。

## 2026-09-17 架构收敛 + CI 构建层 + 文档重构（Fedora 44 / WSL2 standalone Nix）

改动：本地用户名单点移至仓库根 `meta.json`（`flake.nix` 经 `builtins.fromJSON` 读取；`bootstrap.sh`/`linux.sh`/`nixos.sh` 改为 sed 解析同一文件并在解析失败时中止——删掉了三处 `xuqihao` 静默兜底与 `darwin.sh` 的硬编码默认 target）；`pkgsFor` 统一实例化 unstable + stable（共享 `nixpkgsConfig`），`mkStandaloneHome` 不再内联 `import nixpkgs`；`stateVersion` 收敛到 flake 顶层单点并经 `specialArgs`/`extraSpecialArgs` 贯通 `home.stateVersion` 与 `system.stateVersion`；删除无消费者的 `supportedSystems`/`forAllSystems`；`hms` 从别名字符串改为 bash 函数（`programs.bash.initExtra`）；`eval.yml` 增加 standalone x86_64 activation package 构建步（含 runner 磁盘清理，timeout 30→45）；验证后移除共享 `nixpkgsConfig` 中无引用的 `electron-38.8.4`；验证记录拆至本文件。

验证（本机求值/构建，未激活）：五输出求值全部通过，`nixos`/`wsl` toplevel drvPath 与改动前基线**逐字节一致**（干净树对比；含移除 electron 条目后复测），standalone x86_64/aarch64/darwin 按预期变化——经 activationScripts / environment.etc / systemd.units / home.file / bash 选项的 JSON 语义 diff 确认差异仅为 standalone 侧 bashrc 中 `hms` 的别名→函数文本，NixOS 侧无任何语义差异。过程中发现并记录一个 HM 陷阱：`initExtra` 用字符串级 `lib.optionalString` 置空会生成多一个空行的 bashrc（与未设置不同），必须属性集级 `lib.optionalAttrs` 门控。五个 bootstrap 脚本 `bash -n` 通过；sed 提取 stub 测 6 例（正常/缺 key/缺文件/紧凑 JSON/仓库实文件/中止分支）全过；新 CI 构建步本地预演成功（除 HM 自身 5 个派生外全部 substituter 命中，成本可控）；`electron-38.8.4` 移除经五输出求值 + standalone 构建双向验证。

未验证：任何主机的实际激活、aarch64 实机构建、macOS、bootstrap 安装链路实跑、GitHub Actions 上新 workflow 步的运行（workflow 变更需手动双推后才生效）。

## 2026-09-17 follow-up pass on Fedora 44 / WSL2 standalone Nix (offline evaluation)

`bootstrap/bootstrap.sh` had been committed with mode 644 — fixed to 755 to match its siblings; the zsh session-vars append in `home/standalone-linux.nix` is now gated exactly like fish (login shell is zsh or `~/.zshrc` already exists), so bash-only hosts no longer get a stray `~/.zshrc` created on the next activation — this supersedes the unconditional zsh append described in the boundary-expansion entry below (whose live activation test ran in the separate Ubuntu 26.04 distro, not on the daily-driver Fedora 44 host where the committed blocks are still unactivated); README/AGENTS environment wording regularized (validation records name their distro explicitly; the README status table no longer pins the volatile distro name). All five outputs re-evaluate on the current lock after the gating edit; all bootstrap scripts pass `bash -n`. Unverified: live activation of the gated blocks on any host.

## 2026-09-17 boundary expansion on Ubuntu 26.04 / WSL2 standalone Nix (live host)

Added `homeConfigurations.xuqihao-aarch64` (aarch64-linux; shared Linux-only packages verified available at the locked revs — root 6.40.00 not broken, in platforms); `hms` and the new unified entry `bootstrap/bootstrap.sh` now select the standalone target by architecture; standalone Linux gained idempotent guarded zsh/fish session-vars appends in `home.activation` (live-activated here — the `~/.zshrc` guard block was created; fish only acts when fish is actually in use); `bootstrap/linux.sh` gained a WSL1 rejection, a single-user install branch (official installer `--no-daemon` for no-systemd/no-sudo hosts, mirrors in user-level nix.conf plus exported `NIX_CONFIG`, `/nix` one-time-root pre-flight with the exact admin command) and HM-symlink skip guards on the token/flakes steps (previously darwin-only). All five outputs evaluate on the current lock; desktop and WSL toplevel drvPaths are byte-identical to the previous commit, the darwin activation derivation is unchanged, and the x86_64 standalone drvPath changed as expected (hms alias text + new activation blocks). The unified entry ran end-to-end on the live host — a non-tty session auto-selected the single-user branch and exercised its idempotent guards, producing generation 2 — and dispatcher branches were stub-tested (Darwin, WSL1, aarch64/riscv64, zsh note, FreeBSD, explicit-arg override, suffix stripping). Unverified: an aarch64 hardware build, a genuinely rootless single-user install on a machine without sudo, and macOS.

## 2026-09-17 username single-point refactor on Fedora 44 / WSL2 standalone Nix (offline evaluation)

The local username is now defined once as `username = "xuqihao"` at the top of `flake.nix`'s `let` and flows to all NixOS modules and HM entries via `specialArgs`/`extraSpecialArgs` (`users.users.*`, `home-manager.users.*`, standalone output names, `mnt.nix` mount owner); `hms` gained a current-user guard that refuses cleanly on mismatch; `bootstrap/linux.sh`/`darwin.sh` abort up front when the target's username differs from the current login user; `bootstrap/nixos.sh` reads the password-setup username from `flake.nix`. All four outputs evaluate on the current lock; desktop and WSL toplevel drvPaths are byte-identical to the previous commit (semantics-preserving under the default username), standalone drvPaths changed as expected (new `hms` alias text). The `hms` accept/refuse branches, the bootstrap refusal and the flake-username extraction were runtime-tested locally with stubs. Nothing was built or activated; desktop boot, Darwin build and WSL activation remain unverified.

## 2026-09-16 repair/cleanup pass on Fedora 44 / WSL2 standalone Nix (offline evaluation)

After removing the stale `programs.dms-shell.enableSystemMonitoring` definition (removed upstream in the locked nixpkgs; it had broken desktop evaluation since the 2026-09-14 lock bump), all four outputs evaluate — desktop toplevel (hermes-agent input stubbed locally due to GitHub 429), WSL toplevel, standalone Linux and standalone Darwin activation packages. WSL and standalone Linux drvPaths were byte-identical across the P0/P1 edits, confirming those were semantics-preserving. Changes this pass: rustdesk-server disabled (placeholder relay host), podman commented out (docker stays), niri/hypr dotfiles now deployed via `home/default.nix`, orphan dotfiles deleted, `hms` gated behind `isStandalone`, the unused nixpkgs-master channel removed (flake.nix + flake.lock + all plumbing), plasma6/gnome kept with cosmic commented out. None of this was built or activated; desktop boot, Darwin build and WSL activation remain unverified.

## 2026-09-14 runtime split validation on NixOS 26.11 / WSL2

WSL system closure and standalone Linux activation package built without activation; standalone Darwin activation derivation and desktop system derivation evaluated. Desktop/WSL Node, pnpm, Python, R and ROOT package paths match exactly. The built WSL profile passed Node/npm/pnpm/uv execution, npm registry queries, all 15 configured Python module imports, and ROOT/R computations through PyROOT/rpy2. After restoring shared C++ ROOT, WSL and standalone Linux were rebuilt and the standalone artifact passed a C++ ROOT computation. This does not verify activation of these edits, a Darwin build, or desktop boot. Desktop full build remains unverified after a QQ source download failure; further QQ diagnosis was skipped and QQ is unchanged at the user's request.

## 2026-09-05 historical verification on AlmaLinux 9.8 / WSL2 standalone Nix

WSL's system closure built; the desktop host-layout refactor preserved its derivation; standalone Linux/Darwin activation derivations evaluated. These records predate later edits and do not certify the current lock/package set. Activation and subsequent boot/login of the current WSL edits, and a Darwin build, remain unverified; the 2026-09-14 checks exercised build artifacts without activating these edits. GitHub synchronization was separately verified by pushing a documentation commit only to Gitee and observing Actions update GitHub.
