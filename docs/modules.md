# 模块注册表与机器本地选配（机制细节）

2026-10-11 引入的跨前端模块化：**可选软件层与 NixOS-desktop 粒度一致，按机器自由启停**。NixOS 主机、NixOS-WSL、standalone Linux（含非 NixOS 的 WSL 发行版）三类前端共用同一份层目录；darwin 保守处理（白名单制，当前白名单为空）。用户操作前端是 `roam module`（见 [roam.md](roam.md)），本页记机制、边界与踩坑。

## 目录与单一事实源

```
modules/registry.json            # 注册表（单一事实源）：模块名 + nixos/home/darwin 三面旗标 + 描述
modules/<名>/nixos.nix           # 系统级实现（nixos 与 NixOS-WSL 主机共用，原 modules/desktop/<名>.nix 迁入）
modules/<名>/home.nix            # 用户级包列表入口（standalone）
modules/<名>/packages.nix        # 两前端共享的纯应用列表；系统工具/服务留在 nixos.nix
modules/desktop/                 # 桌面基座（session/niri/core/locale-zh），不可选、不在注册表
lib/selection.nix                # 选择解析器：selection / selectionModule / metaModule
local.<主机键>.json               # 机器本地选配（gitignored，roam module 生成维护）
```

- **基座不可选**：`profiles/nixos-base.nix`（系统基座 + 运行时 + GC）、桌面基座（session/niri/locale-zh/core，经 `profiles/desktop.nix`）、`profiles/cli.nix`（WSL 的 CLI 列表）、standalone 的 `common.nix + cli-dev.nix`。`packages/cli-dev.nix` 仍是不拆的四安装点共享 CLI 列表——模块层叠在其上。
- 注册表是**双消费源**：Nix 侧 `lib/selection.nix` 用 fromJSON，bash 侧 `roam.sh load_registry` 用 jq——两路消费者不依赖 JSON 排版；`tests/module-registry.sh` 核对旗标与文件实态（home=false 却有 home.nix 的"静默不可达"是重点盯防形态）。
- 文件位置按约定派生（`modules/<名>/{nixos,home}.nix`），注册表只记名字与旗标——**必须用路径字面量插值**构造（`../modules/${名}/home.nix`）：`../. + 字符串` 拼出的绝对路径在纯求值下禁止 import（2026-10-11 /tmp 尖刺实证）。

## 两视图求值语义（核心机制）

| 视图 | 谁在用 | local 文件 | 生效选择 |
|---|---|---|---|
| git 视图（裸 `.#` / 锁定 `rev` 的 Git 引用） | CI eval job、pre-push 推送快照、远端 `git+https` 装机、手工 `nix build .#` | 不可见 | 入库默认集 |
| `path:./.` 视图 | **roam 全链路**（switch/status/doctor/check）、CI module-matrix | 可见 | 本机选配 |

`local.<主机键>.json` 存在时其 `modules` 列表是**权威完整选择**（整体替换默认集，不做增量合并）；不存在时走调用方显式给出的入库默认集（写在 `hosts/<主机名>/default.nix` / standalone 入口的 `default = []`——延续 explicit-imports 精神，默认组合在 git 里可见可审）。`hosts/nixos` 默认 = 除 android 外的 11 层全集（= 原 profiles/desktop.nix；android 层因含 unfree 的 Android Studio，循 ba5973a 闭源清理惯例仅在显式 enable 的机器上启用），`hosts/wsl` 与 standalone 默认 = 空集（= 原组合）。

主机键（hostKey）：NixOS = 主机名（hosts/<主机名>/）；standalone = 输出名（`x86_64-linux` / `aarch64-linux` / `aarch64-darwin`）。

fail-loud 守卫（`lib/selection.nix` throw，`roam module` 同规则前置拒绝）：未知名 / 该前端无实现 / darwin 白名单外 / local 文件 `host` 字段与输出名不符（防输出改名后旧文件静默生效）。

`roam.selectedModules` 是只读元信息，由每个入口唯一赋值。option 本身不设
default：Nix 模块系统在 readOnly 检查中把 default 也计作一次定义，会与入口
赋值冲突。构建路径未必消费元信息，因此 `checks.<system>.selection-metadata` 单独
强制读取五输出元信息，并验证非空值可读、第二次赋值被拒绝。

## 复现边界（如实记录）

- **远端 `git+https` 装机得到的是入库默认集**（git 视图看不到目标机的 local 文件）；装机后 `roam module init` 以当前有效选择为种子生成 local 文件（首次零行为变化），再 enable/disable 本地化。
- CI eval job 验证默认集；pre-push 使用 stdin 协议中的待推送 commit SHA 验证默认集，未提交修改与 local 选配不进入该快照；roam 使用 path: 验证检出中的本机选配，CI module-matrix 写 local 文件覆盖非默认组合。见 [roam 的推送快照机制](roam.md#pre-push验证推送快照)。
- 手工裸用 `nix build .#attr` = git 视图 = 默认集；要本机选配语义请用 `path:./.#attr` 或直接 `roam`。
- 一台机器一个检出 = 一份选配（local 文件在检出内、随检出走）；同一检出可为他机预配置（`roam module enable X --host <键>`，NixOS 键要求 `hosts/<键>/` 在）。

## darwin 白名单（保守边界）

darwin 输出读 local 文件，但仅接受注册表 `darwin: true` 的模块——当前白名单为空，即 darwin 的 local 文件只能为空集（默认组合不变）。放开某模块 = registry 一行改 true + 该模块 home 部分在 darwin 上求值/构建验证。

## CI 覆盖（eval.yml → module-matrix job）

- 每模块单开隔离求值：nixos 前端在 `nixos` 主机、home 前端在 `x86_64-linux`（单层的求值死亡不被其它层掩盖）；
- wsl 主机全开集求值（wsl 上下文：无硬件配置、nixos-wsl 模块在——agents 层的 `services.hermes-agent` 选项依赖 hermes 模块在 wsl 输出同挂，2026-10-11 补）；
- darwin 白名单负例（白名单外模块必须被 throw）；
- 全开集 x86_64 activationPackage **构建**（非默认组合的 buildEnv 冲突兜底；闭包 ~25GB，job 内额外磁盘清理；android 层的 SDK/Android Studio 下载另计 +4GB 左右）。
- 矩阵清单直接解析 registry.json，无静态清单可漂移。

## 踩坑记录（机制落地时实证）

1. **纯求值下的动态 import**：`../. + "/modules/x.nix"` 抛 "access to absolute path is forbidden"；路径字面量插值 `../modules/${名}/nixos.nix` 合法且随源复制。文件位置约定化后注册表不再记路径。
2. **`map` 与 `concatMap`**：home.nix 是"返回列表的函数"，`map (f: import f …) sel.files` 得到列表的列表，拼进 `home.packages` 后元素是嵌套列表 → "not of type package"（报错显示的恰是嵌套层）。用 `builtins.concatMap`。
3. **EOL 顺序拒评**：standalone unstable 实例全开组合先拒 electron-40.10.5（cherry-studio → electron_40）、放行后再拒 pnpm-10.29.2——nix 一次只报一个，与桌面系统级实例同款依赖对，共享 config 补齐两条（allow-only，无引用者 drvPath 不变）。
4. **local 文件严格 JSON**：写入选配的末元素不能带尾逗号（`fromJSON` 不容忍）；`roam.sh local_selection_write` 的产出由单测以 jq 三态断言（多元素/单元素/空集）锁死。
5. **set -e 管道赋值**：`cur="$(printf … | grep -vxF x)"` 在滤空输出时 rc=1，函数静默中止——`|| true` 兜住；单测桩内须还原 `set -e` 生产语义否则假通过。

## 共享列表与 JSON 接口

可选层的 `packages.nix` 返回两前端共享的应用列表；`home.nix` 转发该函数，
`nixos.nix` 安装同一列表并声明系统服务及额外工具。dev 的 clang、裸 neovim、
distrobox 与 MySQL 仍只在系统端；wechat overlay 仍随 office 的系统端启停。
这次抽取保留现有包选择，不把基础 CLI 或开发服务进一步拆成新开关。

roam 在安装后使用共享 CLI 清单提供的 jq；注册表与本地选配可经过标准 JSON
格式化或压缩，含义不变。本地选配写入前检查模块数组类型和 host 一致性，
坏文件原样保留并报错。bootstrap 在安装 Nix/jq 前仍用自持 meta.json 的轻量
读取方式。Shell 守卫、注册表结构与文件实态由 tests/ 验证。

## 通道异常的历史依据

2026-10-02 snapshot (current allowlists live in `flake.nix` and `profiles/nixos-base.nix`):

| nixpkgs instance | Location | `permittedInsecurePackages` |
|---|---|---|
| Stable **and** standalone unstable (shared) | `flake.nix` → `nixpkgsConfig` (consumed by `pkgsFor` for both channels) | `electron-41.10.7` (successor of `electron-41.9.1`, added 2026-09-26, bumped 2026-10-02: the 2f90778 flake update moved stable's `electron_41`, and the desktop closure consumes stable `electron_41` — probe: stable `electron_41` = 41.10.7, unstable's = 41.10.6, so the refused 41.10.7 could only come from this config's stable instance. Replaced, not accumulated: the old version has no referents left. Standalone doesn't reference it; allow-only semantics leave its drvPath unchanged, byte-identical verified) |
| NixOS unstable, desktop/WSL | `profiles/nixos-base.nix` | `electron-40.10.5`, `pnpm-10.29.2` (both re-verified still load-bearing 2026-10-02: removing either breaks desktop eval — unstable's `electron_40` is still 40.10.5 and the GNOME chain still pins pnpm 10.29.2, even though top-level probes say `electron`/`electron_41` = 43.6.0/41.10.6 and `pnpm` = 12.3.4 — versioned/pinned references are invisible to top-level attr probes; entry liveness is proven by evaluating the affected outputs, nothing else) |

These lists deliberately differ (per-instance needs). Add an approved exact package/version exception to every affected instance in both files as needed; do not assume one edit covers every output or expand permissions just to make documentation match. Validate the affected package/target after changing exceptions. Note that a flake bump can surface **multiple sequential refusals** (Nix reports one at a time — the 2026-10-02 fix unblocked stable's electron first, then unstable's electron/pnpm appeared behind it); keep re-evaluating until the target passes.

`pnpm-10.29.2` on system unstable is referenced only by the desktop closure (GNOME module chain via `services.desktopManager.gnome`); the WSL toplevel derivation is byte-identical without it (verified 2026-09-14). It must still be declared in the shared `profiles/nixos-base.nix`: `nixpkgs.config` merges shallowly across modules, so a second `permittedInsecurePackages` list in `profiles/desktop.nix` would shadow the `electron-40.10.5` entry instead of extending it.
