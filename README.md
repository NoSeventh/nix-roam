# nix-roam

一套跟着我在不同机器间漫游的 Nix 环境。

`nix-roam` 用同一个 flake 同时维护便携的命令行开发环境和完整的 NixOS 桌面配置。普通 Linux / WSL 使用 standalone Home Manager；NixOS 桌面与 NixOS-WSL 使用系统配置，并共享同一套 CLI 工具与用户配置。

## 支持模式

| 模式 | Flake 输出 | 状态 | 用途 |
|---|---|---|---|
| Linux / WSL（x86_64） | `homeConfigurations.xuqihao` | 构建通过；作者的 WSL2 standalone 实机日常在用 | 纯用户级 CLI 环境，不要求宿主机是 NixOS |
| Linux / WSL（aarch64） | `homeConfigurations.xuqihao-aarch64` | 求值通过，未实机构建 | ARM SBC / Asahi 等的纯用户级 CLI 环境 |
| NixOS-WSL | `nixosConfigurations.wsl` | 构建与运行时冒烟通过，本次改动未激活 | 共享基础 CLI，另加 NixOS 专用开发运行时 |
| NixOS | `nixosConfigurations.nixos` | 保留 | x86_64-linux 完整系统、桌面与服务配置 |
| macOS | `homeConfigurations.xuqihao-darwin` | 结构就绪、未实测 | aarch64-darwin 纯 CLI 环境 |

> 这是带有用户名、Home 路径、Git 身份和个人 SSH 主机等信息的个人配置。本地用户名在仓库根 `meta.json` 单点定义（`"username": "xuqihao"`），换登录名只改这一行——standalone 输出名（`.#xuqihao` / `.#xuqihao-aarch64` / `.#xuqihao-darwin`）、NixOS 用户创建、`hms` 函数目标与 bootstrap 默认 target 都随之联动；`bootstrap/linux.sh`/`darwin.sh` 会在目标用户与当前登录用户不符时直接拒绝，脚本解析不到 username 时也会明确报错而非回落默认值。远程 IHEP/JUNO 账号与 git 身份在 `home/common.nix`，需单独调整。直接复用前，请先搜索 `xuqihao` 并按自己的环境核对。

表中验证状态来自历史记录，不代表当前提交的全部输出已重新构建；具体验证环境（发行版 / 主机）以各条验证记录为准，状态表不钉住易变的发行版名。macOS 仅支持 Apple Silicon（aarch64-darwin），standalone Linux 提供 x86_64 与 aarch64 两个显式输出（NixOS 输出仍为 x86_64-linux）。

2026-09-14 在 NixOS 26.11 / WSL2 验证运行时拆分：WSL 系统闭包与 standalone Linux activation package 构建通过，桌面系统 derivation 与 standalone Darwin activation derivation 求值通过；桌面/WSL 运行时路径一致，WSL 构建产物的 Node/npm/pnpm/uv、15 个 Python 模块导入及通过 PyROOT/rpy2 调用的 ROOT/R 计算通过。恢复共享 C++ ROOT 后重新构建 WSL 与 standalone Linux，并从 standalone 构建产物执行 C++ ROOT 计算通过。未激活本次修改；桌面完整构建曾因 QQ 下载失败中止，按用户要求未继续排查或调整 QQ；未验证桌面启动或 Darwin 构建。

2026-09-17 边界拓展在 Ubuntu 26.04 / WSL2 standalone Nix 实机验证：新增 `xuqihao-aarch64`（aarch64-linux）输出，共享 Linux-only 包在锁定 rev 上确认 aarch64 可用（root 非 broken、在 platforms 内）；`hms` 别名与统一入口 `bootstrap/bootstrap.sh` 按架构自动选择 target；standalone Linux 激活时幂等追加 zsh/fish 会话环境加载段（在该 Ubuntu 26.04 distro 实测生成了带守卫的 `~/.zshrc` 段）；`bootstrap/linux.sh` 增加 WSL1 拒绝、单用户安装分支（无 systemd / 无 sudo 时官方安装器 `--no-daemon`，镜像写用户级 nix.conf）与 HM symlink 跳过守卫。五个输出全部求值通过；nixos/wsl toplevel 与改动前逐字节一致，darwin 输出一致，x86_64 standalone 因 hms 文本与激活块按预期变化。统一入口在该 distro 端到端跑通（非交互会话自动落入单用户分支，实测其幂等守卫；激活为 generation 2）；调度器分支以桩测覆盖（Darwin / WSL1 / 架构 / 非 bash / 显式参数）。未验证：aarch64 实机构建、真实无 root 机器上的单用户安装、macOS。

2026-09-17 后续修订在 Fedora 44 / WSL2 standalone Nix 验证：`bootstrap/bootstrap.sh` 补齐执行位（此前误提交为 644，其余脚本均为 755）；zsh 会话环境追加段改为与 fish 同款的「实际使用」门控（登录 shell 是 zsh 或 `~/.zshrc` 已存在才追加），bash-only 的机器激活后不再凭空创建 `~/.zshrc`；验证记录的环境表述规范化（显式注明 distro，状态表不再钉住发行版名——日常在用的 standalone 主机是 Fedora 44 / WSL2，与边界拓展激活测试所用的 Ubuntu 26.04 distro 是两套环境）。五个输出在当前 lock 重新求值通过，bootstrap 脚本全部通过 `bash -n`；带门控的激活块尚未在任何主机实机激活。

## 主要内容

- Home Manager 管理的 Bash、Git、SSH、Starship、Helix、NixVim、Fastfetch 与 btop 配置
- 跨平台共享的现代 CLI、Git 工具、C/C++、Rust、Go、uv、Typst 与 AI 辅助工具；Node/npm 和 Python 科学计算环境仅在 NixOS 安装
- Linux / WSL 上不依赖 root profile 的便携用户环境
- NixOS 上的 Niri 桌面、GUI 应用、服务与虚拟化配置
- 面向中国大陆网络的 Nix binary cache 和 npm 镜像配置
- unstable 与 stable 两套 nixpkgs 通道，按软件稳定性选用

## 快速开始

### 一键安装（无需克隆）

所有场景共用一条命令 —— `bootstrap/bootstrap.sh` 是统一入口，自动检测环境（macOS / NixOS / NixOS-WSL / 普通 Linux / WSL、x86_64 / aarch64、有无 systemd 与 sudo、登录 shell）并派发到对应引导链路，参数原样透传：

```bash
bash <(curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/bootstrap.sh)
```

普通 Linux / WSL 上会自动把仓库取到 `~/nix-roam`（`CLONE_DIR` 环境变量可覆盖；无 git 时退到 Gitee 压缩包）再执行；NixOS 链路需要 root，非 root 运行入口会自动 `sudo` 拾起；standalone Linux 的 flake target 按架构自动选择（x86_64 → `xuqihao`，aarch64 → `xuqihao-aarch64`）。有 systemd + sudo 时走多用户 Determinate 安装（镜像信任写 `/etc/nix`）；无 systemd 或无 sudo 时走单用户安装（官方安装器 `--no-daemon`，镜像写用户级 nix.conf；`/nix` 前缀仍需一次性 root 创建，脚本会给出管理员命令）。WSL1 不受支持，会明确报错。

`bash <(...)` 的写法保留终端交互（可直接粘贴 GitHub token，sudo 密码提示同理）；换成 `curl ... | bash` 也能运行，但会跳过 token 提示。刚导入、默认以 root 进入且连 curl 都没有的 NixOS-WSL：

```bash
nix-env -f '<nixpkgs>' -iA curl && curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh
```

（下载后再运行而不是 `sudo bash <(curl ...)`，是因为 sudo 会关闭继承的文件描述符。）

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

一键命令会自动把仓库取到 `~/nix-roam`（`CLONE_DIR` 环境变量可覆盖；无 git 时退到 Gitee 压缩包）再执行；等价的手动流程：

```bash
git clone https://gitee.com/qihaoxu/nixos-niri-noctalia.git ~/nix-roam
bash ~/nix-roam/bootstrap/bootstrap.sh
```

脚本会依次安装 Nix（systemd + sudo → 多用户 Determinate；否则单用户 `--no-daemon`，见一键安装小节）、配置国内缓存（多用户写 `/etc/nix` daemon 信任，单用户写用户级 nix.conf）、可选配置 GitHub token、开启 flakes、备份可能冲突的用户文件、安装 Home Manager，并激活按架构选择的 target（x86_64 → `xuqihao`，aarch64 → `xuqihao-aarch64`）。token 保存在仓库外的 `~/.config/nix/github-access-tokens.conf`（0600），用来缓解 Nix 获取 GitHub 输入时的 API 限流，与 Git 推送认证及 `gh auth login` 分开。

脚本会跳过部分已完成步骤；Home Manager 已接管配置后，日常更新直接使用 `home-manager switch`（或 `hms` 别名，自动选择当前架构的 target）。激活后打开新登录 shell；原 SSH 配置中需要保留的主机请合并到 `home/common.nix`。实际使用 zsh / fish 时（登录 shell 是它，或对应 rc 文件已存在），激活会幂等追加 HM 会话环境加载段（fish 未装 bass 时仅加 PATH）；bash-only 的机器不会凭空创建这些文件。

### NixOS 全新安装与迁移

`bootstrap/nixos.sh` 覆盖 NixOS 侧两条链路，自动检测模式（`/etc/NIXOS` 存在即 adopt）与 flake 目标（WSL 内核特征 → `.#wsl`，否则 `.#nixos`），也可用子命令强制指定；`--target` 可传任意主机名（见下方「新 NixOS 机器」）。

实体机全新安装：从 NixOS 安装 ISO 启动后，手动分区并把目标盘挂载到 `/mnt`（ESP 挂 `/mnt/boot`，参考命令见脚本头部注释），再以 root 运行：

```bash
curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/nixos.sh -o nixos.sh
bash nixos.sh install
```

脚本会配置国内镜像、可选配置 GitHub token、克隆仓库到 `/mnt/etc/nixos`、按当前磁盘重新生成 `hosts/<target>/hardware-configuration.nix`（默认 target 为 `nixos`，原版备份在同目录）、执行 `nixos-install` 并为 `meta.json` 定义的本地用户设置登录密码；分区与格式化不在脚本职责内。

在已运行的 NixOS 或刚按官方文档导入的 NixOS-WSL 上迁移到本仓库（未克隆仓库时用一键安装小节的对应命令）：

```bash
sudo bash bootstrap/nixos.sh          # 等价于 adopt 子命令
```

迁移链路会整体备份旧的 `/etc/nixos` 再克隆本仓库；若目标系统原有 `system.stateVersion` 与仓库共享值不同，脚本会要求先在主机入口用 `lib.mkForce` 保留原值。两条链路都要求 root，且可安全重复运行。

新 NixOS 机器（第三台起）：在目标机上直接 `sudo bash bootstrap/nixos.sh adopt --target <新主机名>`（实体机全新安装同理加 `install`）。`hosts/<主机名>/` 不存在时，脚本从 `hosts/_template/` 复制出主机目录（自动替换主机名占位符），打印桌面/CLI 两种 flake 输出样例块，等你完成 `variables.nix` 旋钮、GPU profile（`profiles/hardware/`，可不选）和输出块粘贴后校验继续——脚本不自动改 `flake.nix`。约定主机目录名 = `networking.hostName` = flake 输出属性名。`adopt` 已有系统时把原机 `hardware-configuration.nix` 拷进新目录；`install` 链路会自动重新生成。

### NixOS 桌面

NixOS 桌面模式是针对特定机器的个人系统配置，需要配套的 `hardware-configuration.nix`。当前机器的配置位于 `hosts/nixos/` 并纳入版本控制，以保证 Git Flake 可以纯求值和重复构建；其他机器应建立独立的 `hosts/<hostname>/`（从 `hosts/_template/` 模板复制，或用 bootstrap 的 `--target` 脚手架），不要直接复用现有硬件配置。

在已准备好硬件配置的目标机器上：

```bash
sudo nixos-rebuild switch --flake .#nixos
```

### NixOS-WSL

先按 [NixOS-WSL 官方安装说明](https://nix-community.github.io/NixOS-WSL/install.html) 安装 NixOS 发行版，再在其中克隆本仓库并执行：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

刚导入的发行版也可以直接运行 `sudo bash bootstrap/nixos.sh`：脚本会识别 WSL 走 adopt 链路，完成克隆与切换。全新导入的发行版连 curl 都没有，直接用一键安装小节的最后一条命令（先经 `nixpkgs` 通道装 curl，下载后以 root 运行）。

默认用户由 `meta.json` 的 username 定义（当前为 `xuqihao`），主机名为 `wsl`。系统和 Home Manager 一起激活，无需另外运行 `home-manager switch` 或 `bootstrap/linux.sh`。首次接入已有系统时保留该系统原有的 `system.stateVersion`，必要时在主机入口用 `lib.mkForce` 覆盖共享值。

该入口复用 `packages/cli-dev.nix` 和 `home/common.nix`：裸 CLI 工具系统级安装，用户配置由集成的 Home Manager 管理。基础 CLI 与 standalone 对齐，保留清单中的 mpv、C++ ROOT 等工具；此外通过 `profiles/nixos-base.nix` 与 NixOS 桌面共享 Node/npm/pnpm、Python 科学计算环境（含 PyROOT）及 R。WSL 适配使用 NixOS-WSL 模块，不导入实体机硬件配置，也不自动加载桌面模块、数据库、容器服务、Hermes 服务或远程挂载。

普通 Ubuntu/AlmaLinux 等 WSL 发行版仍使用上面的 standalone 入口；只有 NixOS 发行版使用 `.#wsl`。

### macOS（未实机构建验证）

全新 Apple Silicon 机器一键安装（装 Nix → 配镜像 → 配 token → 开 flakes → 备份冲突文件 → 装 HM → 激活）：

```bash
bash <(curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/darwin.sh)
```

与先 `git clone` 到本地再运行 `bash bootstrap/darwin.sh` 等价。

已有 Nix + Home Manager 的机器，在仓库根目录手动激活：

```bash
home-manager switch --flake .#xuqihao-darwin
```

这个入口只管理用户 CLI 环境，不管理 macOS 系统服务和 GUI，也不安装 nix-darwin；不要运行 Linux 引导脚本（统一入口 `bootstrap/bootstrap.sh` 会自动派发，无需手动区分）。flake 仅提供 aarch64-darwin 输出，Intel Mac 不受支持。

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
home-manager switch --flake .#xuqihao        # aarch64 机器用 .#xuqihao-aarch64；或直接用 hms 别名自动选择
```

上面的更新使用仓库锁定的依赖版本。需要升级依赖时，运行 `nix flake update`，检查 `flake.lock` 差异并构建验证，再提交锁文件；`nix-channel --update` 不会更新 flake 依赖。

只验证构建、不激活：

```bash
nix build --no-link .#homeConfigurations.xuqihao.activationPackage
```

aarch64 输出需在 ARM 实机上构建；x86_64 主机（以及 CI）只做求值验证：

```bash
nix eval --raw .#homeConfigurations.xuqihao-aarch64.activationPackage.drvPath
```

验证 NixOS 系统闭包：

```bash
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.wsl.config.system.build.toplevel
```

GitHub 侧的 `eval` workflow（`.github/workflows/eval.yml`）在做上述五条求值之外，还会实际构建 x86_64 standalone activation package——求值拦不住的 Home Manager buildEnv 冲突（如 gcc+clang、双 `python3.withPackages`）在这一层才会暴露。它在 Gitee 同步之后运行，属于事后报警而非 push 前拦截；NixOS toplevel 与 aarch64 仍只做求值。按日期的验证记录见 [`docs/VALIDATION.md`](docs/VALIDATION.md)。

## 目录结构

```text
.
├── flake.nix                   # 双模式 flake 输出与两套 nixpkgs 通道（unstable / stable）
├── meta.json                   # 本地用户名单点定义（flake 与 bootstrap 脚本共读）
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
│   ├── bootstrap.sh            # 统一入口：自动检测环境（OS / NixOS / 架构 / sudo）派发到下列脚本
│   ├── linux.sh                # 全新普通 Linux / WSL 引导脚本（多用户 / 单用户两种安装模式）
│   ├── darwin.sh               # 全新 macOS（Apple Silicon）引导脚本
│   ├── nixos.sh                # NixOS 全新安装 / 迁移引导脚本（install / adopt）
│   └── gc.sh                   # 跨平台手动垃圾回收
├── dotfiles/                   # Home Manager 引用的原始配置文件
├── docs/VALIDATION.md          # 按日期记录的验证边界（验证到求值 / 构建 / 激活哪一层）
├── .github/                    # GitHub 同步工作流与操作说明
└── AGENTS.md                   # 架构决策与维护约定
```

## 配置约定

跨模式共享 CLI 工具维护在 `packages/cli-dev.nix`。它会被安装到以下位置：

- NixOS 桌面 / NixOS-WSL：`environment.systemPackages`，因此 `sudo` 环境也能找到相关命令
- 普通 Linux / WSL：Home Manager 的 `home.packages`
- macOS：Home Manager 的 `home.packages`

需要 Home Manager 托管配置文件的 CLI 放在 `home/common.nix`；GUI Home Manager 配置只放在 `home/default.nix`，避免给 WSL 和 macOS 引入桌面依赖。

Node.js（含 npm）、pnpm、Python 科学计算环境（含 PyROOT）和 R 仅由 `profiles/nixos-base.nix` 安装，NixOS 桌面与 WSL 使用完全相同的 stable 包。Python 与 PyROOT 来自同一 Python 包集，Python wrapper 为 rpy2 设置匹配的 `R_HOME`。不要用 pip 修改这套只读环境。

独立的 C++ ROOT 高能物理计算软件与 Python 的 PyROOT 绑定分开配置：`pkgs-stable.root` 保留在 `packages/cli-dev.nix` 的 Linux-only 列表中，普通 Linux、NixOS 桌面及 WSL 均安装，macOS 保持原先不安装的范围。它的内部 Python 依赖不等于安装共享的 Python 科学计算环境。

Standalone Linux/macOS 不再显式安装 Node.js/npm、pnpm、上述 Python 科学计算环境及 R，保留独立的 `uv`；standalone Linux 仍安装 C++ ROOT。编辑器或其他应用仍可能通过 Nix 引入内部 Node/Python 依赖，这不代表它们接管项目运行时。npm 镜像与用户级 prefix 配置仍共享：全局安装目录是 `~/.npm-global`，`~/.npm-global/bin` 加入 PATH；standalone 需要自行安装 Node（例如使用原生包管理器或 fnm）。

### 普通 Linux 的 Python 管理

系统 Python 交给 apt/dnf 等原生包管理器，不替换 `/usr/bin/python3`，不用 `sudo pip` 或 `--break-system-packages`。一般项目推荐 uv 管理 Python 版本、项目 `.venv` 和锁文件；uv 本身可以由本仓库的 Nix 配置提供，项目解释器和依赖不必由 Nix 提供。

```bash
uv python install 3.13
uv init --python 3.13 my-analysis
cd my-analysis
uv add numpy pandas matplotlib uproot
uv add --dev pytest
uv run python -c 'import numpy; print(numpy.__version__)'
# 添加项目测试后，使用 uv run pytest 运行。
```

提交 `pyproject.toml`、`uv.lock` 和 `.python-version`，不提交 `.venv`；其他机器用 `uv sync --locked` 恢复环境。独立命令行工具用 `uv tool install <工具>`。从旧 Nix Python 迁移的虚拟环境应保留依赖清单并重新创建，不能假设旧 `.venv` 已脱离 Nix store。

需要 ROOT、R、复杂 C/C++ 动态库的科研项目可优先考虑 conda-forge + micromamba，或者实验组提供的容器/CVMFS 环境；只读取 ROOT 文件时先考虑 uv + uproot。uv 并不自动解决所有系统库、CUDA 或外部科研软件依赖。上述 uv 下载解释器方案针对普通 Linux，不应直接当作 NixOS 的通用方案；NixOS 项目需要额外依赖时优先使用项目级 `nix develop`。

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
- 多用户 Nix 安装需要让 daemon 信任自定义 substituter，`bootstrap/linux.sh` 会处理新机器的这项配置；无 systemd / 无 sudo 的机器走单用户安装，镜像直接写用户级 nix.conf，无需 daemon 授权（`/nix` 仍需一次性 root 创建）。WSL1 不受支持，请先升级 WSL2。
- macOS 输出目前尚未完成真实设备构建验证；`bootstrap/nixos.sh` 的两条链路同样尚未实机验证。aarch64 Linux 输出与单用户安装链路当前也仅求值/桩测验证，未在 ARM 或无 root 机器上实测。

## License

见 [`LICENSE`](LICENSE)。
