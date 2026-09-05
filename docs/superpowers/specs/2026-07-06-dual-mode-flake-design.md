# 双模 Flake 设计：NixOS 系统配置 + 非 NixOS 便携 CLI 开发环境

- 日期：2026-07-06
- 状态：已批准（待实现）
- 作者：xuqihao

## 1. 目标

让本仓库的 flake 同时服务两种模式：

1. **NixOS 模式（现状，保持不变）**：在一台 x86_64 NixOS 机器上作为完整系统配置，管理桌面、GUI 应用、系统服务。`sudo nixos-rebuild switch` 行为不变。
2. **非 NixOS 模式（新增）**：在普通 Linux 发行版、WSL、macOS 上，仅用 Nix + Home Manager 在**用户层**快速搭建一套好用的 **CLI 开发环境**（dotfiles + 小众 CLI 工具）。作为原生包管理器的**补充**，不碰系统层。

核心诉求：**在任何能碰到的系统环境，都能马上通过 Nix 搭出一套统一的 CLI 开发环境**；同时保证 NixOS 上 `sudo` 时不丢失对 CLI 工具的访问。

## 2. 非目标（Non-goals）

- **不**在非 NixOS 上做系统层管理（不用 nix-darwin，不写 launchd/systemd 单元）。理由：用户明确"系统层交给原系统，否则直接用 NixOS"。
- **不**用 Nix 管理 GUI 应用（非 NixOS 侧）。所有 GUI（终端模拟器、编辑器 GUI、桌面应用）一律由原生系统负责。Nix 侧**纯 CLI**。
- **不**做 root 独立 Home Manager profile。`sudo` 工具访问问题靠 NixOS 系统级安装解决，不需要 per-user HM。
- **不**在本次实现 macOS 的实际配置。仅做架构预留（`aarch64-darwin` 的 system 实例化 + `xuqihao-darwin` 入口就绪）。

## 3. 现状

- `flake.nix`：仅输出 `nixosConfigurations.nixos`，`system = "x86_64-linux"` 硬编码；`pkgs-stable`/`pkgs-master` 按 `x86_64-linux` 实例化。
- `configuration.nix` + `modules/*.nix`：纯 NixOS 系统级配置（boot、GDM、pipewire、systemd 服务、`environment.systemPackages`、虚拟化）。
- `modules/programs.nix`：桌面软件与可移植 CLI 工具**混在一起**的巨型列表。
- `home/default.nix`：Home Manager 用户配置（git/bash/starship/helix/ssh/终端/dotfiles），但 `/home/xuqihao` 和用户名硬编码；当前作为 NixOS 模块运行。
- `home/nixvim.nix`、`home/fastfetch.nix`：可移植的子配置。

## 4. 核心架构：一份共享 CLI 列表，两种安装位置

把"CLI 开发工具"抽象成一份**纯函数式列表**，按运行模式喂到不同位置：

```
                    ┌─────────────────────────┐
                    │  packages/cli-dev.nix   │   ← 单一事实源
                    │  { pkgs, pkgs-stable }: │     （纯函数，返回 package list）
                    │  [ ripgrep fd gcc ... ] │
                    └───────────┬─────────────┘
                          ┌─────┴─────┐
                 NixOS 模式│           │非 NixOS 模式
                          ▼           ▼
        environment.systemPackages   home.packages
        (/run/current-system/sw/bin) (~/.nix-profile/bin)
                          │           │
        ✓ sudo 可见（在 secure_path）   ✗ sudo 不可见（用户级）
        ✓ 所有用户/root 都能用          ✓ 当前用户即时可用
```

- **NixOS**：CLI 工具装到 `environment.systemPackages` → 进 `/run/current-system/sw/bin` → 在 sudo 的 `secure_path` 内 → `sudo <工具>` 照常工作，root 也可用。**解决 sudo 问题。**
- **非 NixOS**：同一列表喂到 `home.packages` → 装入用户 profile → `home-manager switch` 一条命令到位。此处 sudo 不可控（user-level HM 不碰 sudoers），需要时用 `sudo -E` 兜底；非 NixOS 环境下非主要痛点。

## 5. Flake 输出形态

```
flake outputs:
  nixosConfigurations.nixos          # 不变：x86_64-linux 完整系统（含所有桌面软件）
  homeConfigurations.xuqihao         # 新增：x86_64-linux（WSL / 普通 Linux）
  homeConfigurations.xuqihao-darwin  # 预留：aarch64-darwin（Apple Silicon Mac）
```

- 不要 `darwinConfigurations`（不做系统层）。
- 不要 root profile。
- 平台显式命名（`xuqihao` / `xuqihao-darwin`），不依赖 `--impure` 自动检测，干净可靠。

## 6. 文件结构

```
├── flake.nix                      # 改：参数化 system，加 homeConfigurations + forAllSystems helper
├── configuration.nix              # 不变
├── hardware-configuration.nix     # 不变
├── modules/
│   ├── programs.nix               # 改：environment.systemPackages 末尾追加 ++ (import ../packages/cli-dev.nix)（不剥离现有条目）
│   └── (其余 modules 不变)
├── packages/
│   └── cli-dev.nix                # 新：共享 CLI 开发工具列表（纯函数 → 返回 [ pkgs ]）
├── home/
│   ├── default.nix                # 改：thin 入口 = common + GUI HM + 个人专属
│   ├── common.nix                 # 新：跨平台 CLI-only HM 配置（HM 模块 + dotfiles）
│   ├── standalone.nix             # 新：非 NixOS 入口 = common + 个人专属，零 GUI，Linux/Mac 共用
│   ├── nixvim.nix                 # 不变
│   └── fastfetch.nix              # 不变
├── bootstrap/
│   └── linux.sh                   # 新：fresh Linux/WSL 一键装 Nix + HM 并激活
└── dotfiles/                      # 不变
```

### 6.1 `home/` 拆分原则

- **`common.nix`** —— 纯 CLI，零 GUI 假设，**每个目标都能跑**（NixOS / WSL / 普通 Linux / Mac）。包含 HM 模块：`programs.git`、`programs.bash`、`programs.fish`、`programs.starship`、`programs.helix`、`programs.ssh`、`nixvim`、`programs.fzf`、`programs.bat`、`programs.eza`、`programs.zoxide`、`programs.direnv`、`programs.tmux`、`programs.lazygit`、`programs.btop`、`fastfetch`。以及可移植 dotfiles。
- **`home/default.nix`**（NixOS 入口）—— `imports = [ ./common.nix ];` + GUI HM 模块（`programs.alacritty`、`programs.ghostty`、`programs.fuzzel`、`services.xsettingsd`）+ 个人专属（IHEP ssh 别名、工作目录别名）。**视觉效果与今天完全一致。**
- **`home/standalone.nix`**（非 NixOS 入口）—— `imports = [ ./common.nix ];` + 个人专属。**零 GUI**。Linux 与 Mac 共用；`homeDirectory` 由 HM 按 system 自动决定（Linux `/home/$USER`，Darwin `/Users/$USER`）。

GUI HM 配置**仅留在 NixOS 入口**，不进 `common.nix`、不导出 standalone。

### 6.2 `packages/cli-dev.nix` 与 `modules/programs.nix` 的接入

- `packages/cli-dev.nix`：纯函数 `{ pkgs, pkgs-stable, ... }: [ ... ]`，返回 package list。**单一事实源**，被两处导入：NixOS 的 `modules/programs.nix` 和 standalone 的 `home/standalone.nix`。
- `modules/programs.nix`：在现有 `environment.systemPackages = with pkgs; [ ... ];` 末尾追加 `++ (import ../packages/cli-dev.nix { inherit pkgs pkgs-stable; });` —— 把共享 CLI 工具加进 NixOS 系统级（sudo 可见）。**不剥离现有条目**（避免破坏正在使用的系统；重复条目由 Nix store path 自动去重，无开销）。可选：后续手动从 programs.nix 移除已迁入 cli-dev.nix 的条目。

## 7. CLI 开发环境默认清单

**HM 模块（`common.nix`，带配置）**：git、bash、fish、starship、helix、ssh、nixvim、fzf、bat、eza、zoxide、direnv、tmux、lazygit、btop、fastfetch

**共享列表（`packages/cli-dev.nix`，纯工具）**：

- 现代基础：`ripgrep fd sd dust procs bottom tree tealdeer glow gh`
- 开发工具链：`gcc gnumake cmake ninja clang clang-tools gdb pkg-config rustc cargo go gopls delve nodejs jq python3`
- Nix 工具：`nil nixpkgs-fmt`
- 小众 CLI（从现有 programs.nix 抽）：`yt-dlp sshfs tmux zellij`
- 网络/下载：`wget curl`

> `pkgs` vs `pkgs-stable` 延续现有习惯（追新的走 unstable，重的走 stable）。后续按需往 `common.nix`（要配置的）或 `cli-dev.nix`（纯工具）追加。

## 8. 各平台激活方式

| 环境 | 命令 |
|---|---|
| NixOS（不变） | `sudo nixos-rebuild switch`（或 `nrs`） |
| Fresh Linux/WSL（未装 Nix） | `bash bootstrap/linux.sh`（自动装 Nix + HM 并 `home-manager switch --flake .#xuqihao`） |
| 已有 Nix+HM 的 Linux/WSL | `home-manager switch --flake .#xuqihao` |
| 远程机器（不 clone 仓库） | `home-manager switch --flake "git+https://gitee.com/qihaoxu/nix-roam#xuqihao"` |
| Mac（未来） | `home-manager switch --flake .#xuqihao-darwin` |

## 9. sudo 处理

- **NixOS**：CLI 工具统一进 `environment.systemPackages` → `/run/current-system/sw/bin` → 在 sudo `secure_path` 内。`sudo <工具>` 与 root 直接可用。**无需改 sudoers。**
- **非 NixOS**：user-level HM 无法配置系统 sudoers，属于已知限制。需要时用 `sudo -E`；非 NixOS 环境下非主要场景。

## 10. 迁移影响（对现有 NixOS 配置）

- `flake.nix`：参数化 system；新增 `homeConfigurations`、`forAllSystems` helper；`pkgs-stable`/`pkgs-master` 改为按 system 实例化。**`nixosConfigurations.nixos` 保持等价。**
- `modules/programs.nix`：**最小改动** —— 仅在 `environment.systemPackages` 末尾追加 `++ (import ../packages/cli-dev.nix { inherit pkgs pkgs-stable; });`。**不剥离现有条目**（避免破坏在用的系统；重复由 store 去重），后续可选手动去重。
- `home/default.nix`：重构成 thin 入口（`imports = [ ./common.nix ];` + GUI HM + 个人 ssh 别名）。视觉效果不变。
- 新 `home/common.nix`、`home/standalone.nix`、`packages/cli-dev.nix`、`bootstrap/linux.sh`。
- `configuration.nix`、`hardware-configuration.nix`、其余 `modules/*.nix`、`dotfiles/`：**不动**。

**验收**：改造后 `sudo nixos-rebuild switch` 在 NixOS 机器上效果与改造前一致；`sudo <cli-tool>` 可用；在 WSL/Linux 上 `home-manager switch --flake .#xuqihao` 能装出同一套 CLI 环境。

## 11. macOS 预留（仅留位，不实现）

- flake 里 `xuqihao-darwin` 走 `aarch64-darwin`，导入同一个 `standalone.nix`。
- `pkgs-stable` 在 `forAllSystems` 内为 darwin 实例化（结构就绪）。
- 真正上 Mac 时基本零结构改动，只需按需追加 Mac 专属 CLI。

## 12. 风险与备注

- **programs.nix 不剥离的决定**：为降低破坏在用系统的风险，本次不改写 programs.nix 现有条目，只追加 `++ (import cli-dev.nix)`。代价是部分 CLI 工具在 NixOS 上同时存在于 programs.nix 与 cli-dev.nix（store path 去重，无功能/存储开销）。去重可作为后续可选清理任务。
- **双份安装冗余**：某些工具既被 HM 模块安装（如 `programs.helix`）又出现在 `cli-dev.nix`/`programs.nix`。Nix store path 去重，无实质开销。
- **HM 模块在不同平台的可用性**：个别 HM 模块（如 `programs.fish` 在某些受限环境）需验证；实现阶段以"common.nix 在 WSL/Linux 均可 build"为验收项。
- **`xuqihao-darwin` 未实测**：本次不持有 Mac，预留入口未经实际 build 验证，属于已知未验证项。

## 13. 实施后调整：按主机组织硬件配置

为兼顾多机器可迁移性与 Git Flake 的纯求值要求，NixOS 主机入口调整为：

```text
hosts/nixos/
├── default.nix
└── hardware-configuration.nix
```

- `hosts/nixos/default.nix` 组合共享的 `configuration.nix` 与当前机器生成的硬件配置。
- `hosts/<hostname>/hardware-configuration.nix` 必须纳入 Git；Git Flake 不会复制真正被忽略的文件。
- 根目录 `/hardware-configuration.nix` 继续被忽略，只用于防止在错误位置重新生成。
- 新增机器时创建独立的 `hosts/<hostname>/`，并在 `flake.nix` 增加对应的 `nixosConfigurations.<hostname>`，不覆盖现有主机文件。
- Linux/WSL/macOS 的 standalone Home Manager 输出不依赖任何 NixOS 主机目录，因此可移植模式保持不变。
