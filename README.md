# nix-roam

一套跟着我在不同机器间漫游的 Nix 环境。

`nix-roam` 用同一个 flake 同时维护便携的命令行开发环境和完整的 NixOS 桌面配置。当前主要使用场景是普通 Linux / WSL 上的 standalone Home Manager；原有 NixOS 配置继续保留，并共享同一套 CLI 工具与用户配置。

## 支持模式

| 模式 | Flake 输出 | 状态 | 用途 |
|---|---|---|---|
| Linux / WSL | `homeConfigurations.xuqihao` | 当前使用、已验证 | 纯用户级 CLI 环境，不要求宿主机是 NixOS |
| NixOS | `nixosConfigurations.nixos` | 保留 | x86_64-linux 完整系统、桌面与服务配置 |
| macOS | `homeConfigurations.xuqihao-darwin` | 结构就绪、未实测 | aarch64-darwin 纯 CLI 环境 |

> 这是带有用户名、Home 路径、Git 身份和个人 SSH 主机等信息的个人配置。直接复用前，请先搜索 `xuqihao` 并按自己的环境调整。

## 主要内容

- Home Manager 管理的 Bash、Git、SSH、Starship、Helix、NixVim、Fastfetch 与 btop 配置
- 跨平台共享的现代 CLI、Git 工具、C/C++、Rust、Go、Python、Typst 与 AI 辅助工具
- Linux / WSL 上不依赖 root profile 的便携用户环境
- NixOS 上的 Niri 桌面、GUI 应用、服务与虚拟化配置
- 面向中国大陆网络的 Nix binary cache 和 npm 镜像配置
- unstable、stable 与 master 三套 nixpkgs 通道，按软件稳定性选用

## 快速开始

### 已安装 Nix 和 Home Manager

无需克隆即可激活 Linux / WSL 配置：

```bash
home-manager switch --flake "git+https://gitee.com/qihaoxu/nix-roam#xuqihao"
```

从本地仓库激活：

```bash
git clone https://gitee.com/qihaoxu/nix-roam.git
cd nix-roam
home-manager switch --flake .#xuqihao
```

### 全新的 Linux / WSL

安装 Git 并克隆仓库后，运行引导脚本：

```bash
git clone https://gitee.com/qihaoxu/nix-roam.git
cd nix-roam
bash bootstrap/linux.sh
```

脚本会依次安装 Nix、配置 flakes 与国内缓存、备份可能冲突的用户文件、安装 Home Manager，并激活 `xuqihao` 配置。它设计为可重复运行。

### NixOS

NixOS 模式是针对特定机器的个人系统配置，需要配套的 `hardware-configuration.nix`。该文件包含硬件信息且不纳入版本控制，不建议在其他机器上直接切换。

在已准备好硬件配置的目标机器上：

```bash
sudo nixos-rebuild switch --flake .#nixos
```

## 更新与验证

更新当前 Linux / WSL 用户环境：

```bash
git pull
home-manager switch --flake .#xuqihao
```

只验证构建、不激活：

```bash
nix build --no-link .#homeConfigurations.xuqihao.activationPackage
```

验证 NixOS 系统闭包：

```bash
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
```

## 目录结构

```text
.
├── flake.nix                   # 双模式 flake 输出与三套 nixpkgs 通道
├── configuration.nix           # NixOS 基础系统配置
├── modules/                    # 自动加载的 NixOS 模块
├── home/
│   ├── common.nix              # 两种模式共享的纯 CLI Home Manager 配置
│   ├── default.nix             # NixOS Home Manager 入口，包含 GUI 配置
│   ├── standalone-linux.nix    # 普通 Linux / WSL 入口
│   ├── standalone-darwin.nix   # macOS 入口
│   └── nix-cn.nix              # Nix binary cache 单一配置源
├── packages/cli-dev.nix        # 三个安装位置共享的 CLI 软件列表
├── bootstrap/linux.sh          # 全新 Linux / WSL 引导脚本
├── dotfiles/                   # Home Manager 引用的原始配置文件
└── docs/superpowers/           # 设计说明与实施记录
```

## 配置约定

CLI 工具只维护一份列表：`packages/cli-dev.nix`。它会被安装到以下位置：

- NixOS：`environment.systemPackages`，因此 `sudo` 环境也能找到相关命令
- 普通 Linux / WSL：Home Manager 的 `home.packages`
- macOS：Home Manager 的 `home.packages`

需要 Home Manager 托管配置文件的 CLI 放在 `home/common.nix`；GUI Home Manager 配置只放在 `home/default.nix`，避免给 WSL 和 macOS 引入桌面依赖。

更完整的架构说明见 [`docs/superpowers/specs/2026-07-06-dual-mode-flake-design.md`](docs/superpowers/specs/2026-07-06-dual-mode-flake-design.md)。

## 注意事项

- `hardware-configuration.nix` 是机器专用文件，已被忽略，不应提交。
- NixOS 中的 Hermes Agent 需要目标机器自行提供 `/etc/hermes/env`。
- 多用户 Nix 安装需要让 daemon 信任自定义 substituter；`bootstrap/linux.sh` 会处理新机器的这项配置。
- macOS 输出目前尚未完成真实设备构建验证。

## License

当前仓库尚未声明开源许可证。配置可供参考，但在添加许可证前不代表已授予复制、修改或再分发权限。
