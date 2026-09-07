# nix-roam

一套跟着我在不同机器间漫游的 Nix 环境。

`nix-roam` 用同一个 flake 同时维护便携的命令行开发环境和完整的 NixOS 桌面配置。普通 Linux / WSL 使用 standalone Home Manager；NixOS 桌面与 NixOS-WSL 使用系统配置，并共享同一套 CLI 工具与用户配置。

## 支持模式

| 模式 | Flake 输出 | 状态 | 用途 |
|---|---|---|---|
| Linux / WSL | `homeConfigurations.xuqihao` | 已有使用记录，变更后需重新验证 | 纯用户级 CLI 环境，不要求宿主机是 NixOS |
| NixOS-WSL | `nixosConfigurations.wsl` | 有构建通过记录、待目标机实测 | NixOS 系统管理，软件环境与 standalone Linux 对齐 |
| NixOS | `nixosConfigurations.nixos` | 保留 | x86_64-linux 完整系统、桌面与服务配置 |
| macOS | `homeConfigurations.xuqihao-darwin` | 结构就绪、未实测 | aarch64-darwin 纯 CLI 环境 |

> 这是带有用户名、Home 路径、Git 身份和个人 SSH 主机等信息的个人配置。直接复用前，请先搜索 `xuqihao` 并按自己的环境调整。

表中验证状态来自历史记录，不代表当前提交的全部输出已重新构建；macOS 仅支持 Apple Silicon（aarch64-darwin），Linux 输出为 x86_64-linux。

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
home-manager switch --flake "git+https://gitee.com/qihaoxu/nixos-niri-noctalia.git#xuqihao"
```

从本地仓库激活：

```bash
git clone https://gitee.com/qihaoxu/nixos-niri-noctalia.git nix-roam
cd nix-roam
home-manager switch --flake .#xuqihao
```

### 全新的 Linux / WSL

安装 Git 并克隆仓库后，运行引导脚本：

```bash
git clone https://gitee.com/qihaoxu/nixos-niri-noctalia.git nix-roam
cd nix-roam
bash bootstrap/linux.sh
```

脚本会依次安装 Nix、配置国内缓存信任、可选配置 GitHub token、开启 flakes、备份可能冲突的用户文件、安装 Home Manager，并激活 `xuqihao` 配置。token 保存在仓库外的 `~/.config/nix/github-access-tokens.conf`（0600），用来缓解 Nix 获取 GitHub 输入时的 API 限流，与 Git 推送认证及 `gh auth login` 分开。

脚本会跳过部分已完成步骤；Home Manager 已接管配置后，日常更新直接使用 `home-manager switch`。激活后打开新登录 shell；原 SSH 配置中需要保留的主机请合并到 `home/common.nix`。

### NixOS 全新安装与迁移

`bootstrap/nixos.sh` 覆盖 NixOS 侧两条链路，自动检测模式（`/etc/NIXOS` 存在即 adopt）与 flake 目标（WSL 内核特征 → `.#wsl`，否则 `.#nixos`），也可用子命令强制指定。

实体机全新安装：从 NixOS 安装 ISO 启动后，手动分区并把目标盘挂载到 `/mnt`（ESP 挂 `/mnt/boot`，参考命令见脚本头部注释），再以 root 运行：

```bash
curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/nixos.sh -o nixos.sh
bash nixos.sh install
```

脚本会配置国内镜像、可选配置 GitHub token、克隆仓库到 `/mnt/etc/nixos`、按当前磁盘重新生成 `hosts/nixos/hardware-configuration.nix`（原版备份在同目录）、执行 `nixos-install` 并设置 `xuqihao` 的登录密码；分区与格式化不在脚本职责内。

在已运行的 NixOS 或刚按官方文档导入的 NixOS-WSL 上迁移到本仓库：

```bash
sudo bash bootstrap/nixos.sh          # 等价于 adopt 子命令
```

迁移链路会整体备份旧的 `/etc/nixos` 再克隆本仓库；若目标系统原有 `system.stateVersion` 与仓库共享值不同，脚本会要求先在主机入口用 `lib.mkForce` 保留原值。两条链路都要求 root，且可安全重复运行。

### NixOS 桌面

NixOS 桌面模式是针对特定机器的个人系统配置，需要配套的 `hardware-configuration.nix`。当前机器的配置位于 `hosts/nixos/` 并纳入版本控制，以保证 Git Flake 可以纯求值和重复构建；其他机器应建立独立的 `hosts/<hostname>/`，不要直接复用现有硬件配置。

在已准备好硬件配置的目标机器上：

```bash
sudo nixos-rebuild switch --flake .#nixos
```

### NixOS-WSL

先按 [NixOS-WSL 官方安装说明](https://nix-community.github.io/NixOS-WSL/install.html) 安装 NixOS 发行版，再在其中克隆本仓库并执行：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

刚导入的发行版也可以直接运行 `sudo bash bootstrap/nixos.sh`：脚本会识别 WSL 走 adopt 链路，完成克隆与切换。

默认用户为 `xuqihao`，主机名为 `wsl`。系统和 Home Manager 一起激活，无需另外运行 `home-manager switch` 或 `bootstrap/linux.sh`。首次接入已有系统时保留该系统原有的 `system.stateVersion`，必要时在主机入口用 `lib.mkForce` 覆盖共享值。

该入口复用 `packages/cli-dev.nix` 和 `home/common.nix`：裸 CLI 工具系统级安装，用户配置由集成的 Home Manager 管理。这里“CLI”指与 standalone 的软件环境对齐，保留清单中的 mpv 等工具。WSL 适配使用 NixOS-WSL 模块，不导入实体机硬件配置，也不自动加载桌面模块、数据库、容器服务、Hermes 服务或远程挂载。

普通 Ubuntu/AlmaLinux 等 WSL 发行版仍使用上面的 standalone 入口；只有 NixOS 发行版使用 `.#wsl`。

### macOS（未实机构建验证）

全新 Apple Silicon 机器一键安装（装 Nix → 配镜像 → 配 token → 开 flakes → 备份冲突文件 → 装 HM → 激活）：

```bash
bash bootstrap/darwin.sh
```

已有 Nix + Home Manager 的机器，在仓库根目录手动激活：

```bash
home-manager switch --flake .#xuqihao-darwin
```

这个入口只管理用户 CLI 环境，不管理 macOS 系统服务和 GUI，也不安装 nix-darwin；不要运行 Linux 引导脚本。flake 仅提供 aarch64-darwin 输出，Intel Mac 不受支持。

该配置尊重 macOS 惯用用法：不改默认 shell，也不接管 `~/.zshrc`——首次激活只会向其追加一段幂等的 Home Manager 环境加载（会话变量与 PATH，可整段删除），zsh 的提示符和其余配置保持原生；starship 提示符和 bash 别名只影响 bash 会话，其中 `hms` 在 macOS 指向 `.#xuqihao-darwin`。与 Homebrew 共存时，PATH 中 nix 提供的工具优先于同名 brew 命令。

## 更新与验证

手动垃圾回收（自动识别 NixOS、普通 Linux / WSL 和 macOS）：

```bash
bash bootstrap/gc.sh --dry-run        # 仅预览命令，不执行清理
bash bootstrap/gc.sh                  # 清理超过 14 天的旧世代及无引用的包
bash bootstrap/gc.sh --older-than 30d # 改为保留最近 30 天
bash bootstrap/gc.sh --all            # 清理全部非当前世代，失去这些世代的回滚能力
```

以普通用户运行即可：NixOS 会先清理用户环境，再通过 sudo 清理系统旧世代；普通 Linux / WSL 和 macOS 默认只清理用户环境，需要清理系统/root 世代（例如 nix-darwin）时加 `--system`。当前环境及其他 GC 根引用的包不会被删除；脚本不刷新引导菜单。

更新当前 Linux / WSL 用户环境：

```bash
git pull --ff-only
home-manager switch --flake .#xuqihao
```

上面的更新使用仓库锁定的依赖版本。需要升级依赖时，运行 `nix flake update`，检查 `flake.lock` 差异并构建验证，再提交锁文件；`nix-channel --update` 不会更新 flake 依赖。

只验证构建、不激活：

```bash
nix build --no-link .#homeConfigurations.xuqihao.activationPackage
```

验证 NixOS 系统闭包：

```bash
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.wsl.config.system.build.toplevel
```

## 目录结构

```text
.
├── flake.nix                   # 双模式 flake 输出与三套 nixpkgs 通道
├── hosts/
│   ├── nixos/                  # 当前 NixOS 主机入口（机器专属设置）与硬件配置
│   └── wsl/                    # NixOS-WSL 主机入口
├── profiles/                   # 显式导入的共享 profiles：基础、桌面、locale、CLI
├── modules/                    # 共享 NixOS 模块；modules/desktop/ 为桌面专属模块
├── home/
│   ├── common.nix              # 两种模式共享的纯 CLI Home Manager 配置
│   ├── default.nix             # NixOS Home Manager 入口，包含 GUI 配置
│   ├── nixos-cli.nix           # NixOS CLI 用户配置入口
│   ├── standalone-linux.nix    # 普通 Linux / WSL 入口
│   ├── standalone-darwin.nix   # macOS 入口
│   └── nix-cn.nix              # Nix binary cache 单一配置源
├── packages/cli-dev.nix        # 各入口共享的 CLI 软件列表
├── bootstrap/
│   ├── linux.sh                # 全新普通 Linux / WSL 引导脚本
│   ├── darwin.sh               # 全新 macOS（Apple Silicon）引导脚本
│   ├── nixos.sh                # NixOS 全新安装 / 迁移引导脚本（install / adopt）
│   └── gc.sh                   # 跨平台手动垃圾回收
├── dotfiles/                   # Home Manager 引用的原始配置文件
├── .github/                    # GitHub 同步工作流与操作说明
└── AGENTS.md                   # 架构决策与维护约定
```

## 配置约定

CLI 工具只维护一份列表：`packages/cli-dev.nix`。它会被安装到以下位置：

- NixOS 桌面 / NixOS-WSL：`environment.systemPackages`，因此 `sudo` 环境也能找到相关命令
- 普通 Linux / WSL：Home Manager 的 `home.packages`
- macOS：Home Manager 的 `home.packages`

需要 Home Manager 托管配置文件的 CLI 放在 `home/common.nix`；GUI Home Manager 配置只放在 `home/default.nix`，避免给 WSL 和 macOS 引入桌面依赖。

更完整的架构说明和维护约定见 [`AGENTS.md`](AGENTS.md)。

npm/npx 默认使用 npmmirror，Bash 中可用 `npmr install <pkg>` 临时改用 NJU。默认 registry 环境变量会覆盖项目 `.npmrc`；需要项目自己的源时使用 `--registry=<url>` 或取消 `NPM_CONFIG_REGISTRY`。

## Gitee 与 GitHub 同步

主仓库是 [Gitee](https://gitee.com/qihaoxu/nixos-niri-noctalia)，镜像是 [GitHub](https://github.com/NoSeventh/nix-roam)。项目名为 nix-roam，Gitee 路径仍为 nixos-niri-noctalia。

从 Gitee 克隆后，日常提交只需推送 Gitee：

```bash
git push origin master
```

GitHub Actions 在每小时第 17、47 分钟自动拉取分支和标签，也可在 [Sync from Gitee](https://github.com/NoSeventh/nix-roam/actions/workflows/sync-from-gitee.yml) 页面点击 **Run workflow** 手动同步。定时任务可能延迟；公开仓库 60 天无活动后需重新启用。

同步不会强制覆盖分叉历史或删除 GitHub 独有分支。修改工作流文件时，需要将同一提交手动推送到两边；普通代码和文档更新由 Actions 同步。详见 [同步说明](.github/SYNC.md)。

远程配置只保存在本机，不随提交同步。若另一台电脑从 Gitee 克隆，需要手动推送 GitHub 时先添加：

```bash
git remote add github git@github.com:NoSeventh/nix-roam.git
```

从 GitHub 克隆时 `origin` 指向 GitHub，推送前先用 `git remote -v` 确认目标。

## 注意事项

- `hosts/<hostname>/hardware-configuration.nix` 是机器专用文件，应与对应主机入口一起提交；只有仓库根目录下误生成的 `/hardware-configuration.nix` 被忽略。
- NixOS 桌面配置中的 Hermes Agent 需要目标机器自行提供 `/etc/hermes/env`。
- 多用户 Nix 安装需要让 daemon 信任自定义 substituter；`bootstrap/linux.sh` 会处理新机器的这项配置。
- macOS 输出目前尚未完成真实设备构建验证；`bootstrap/nixos.sh` 的两条链路同样尚未实机验证。

## License

见 [`LICENSE`](LICENSE)。
