# NixOS-WSL CLI 主机入口

- 日期：2026-09-05
- 状态：已实现；用户批准方案，明确 CLI 表示与 standalone 软件环境对齐

## 设计

保留 NixOS 与 standalone Home Manager 两种管理方式。在 NixOS 侧新增 `nixosConfigurations.wsl`，采用显式主机入口，不读取求值机器的内核或环境变量来决定目标。

- `hosts/wsl/default.nix`：WSL 默认用户 `xuqihao`、主机名 `wsl`、基础和 CLI profile。
- `profiles/nixos-base.nix`：共享用户、权限、Nix daemon 镜像设置、时区、locale、包许可与 stateVersion。
- `profiles/locale.nix`：两种 NixOS 主机共用的中文 locale；输入法与字体保留在桌面模块。
- `profiles/cli.nix`：将现有 `packages/cli-dev.nix` 安装至系统级，保持 sudo 可用。
- `home/nixos-cli.nix`：复用 `home/common.nix` 和用户身份，通过 NixOS 的 Home Manager 集成激活。
- `configuration.nix`：保留实体机引导、硬件、桌面和现有服务，导入共享基础。

WSL 不导入 standalone 入口的用户级 Nix 管理设置，也不加载 `generatedModules`。NixOS-WSL input 与根 nixpkgs 对齐并锁定版本，负责 WSL 启动和集成；无实体机 hardware-configuration.nix。

共享软件列表保持原样，包括 mpv 等有图形能力的工具。数据库、容器、Hermes 服务、自动远程挂载等按需另行启用。WSLg 集成遵循上游默认值，不配置 Linux 桌面会话。

## 验证

验证环境为 AlmaLinux 9.8 / WSL2 上的 standalone Nix，未执行系统激活。

- 新 WSL `system.build.toplevel` 完整构建通过。
- 桌面入口拆分前后的系统 derivation 路径一致。
- Linux 与 Darwin standalone activationPackage 均求值通过；Darwin 未做真实构建。
- WSL 桌面、数据库、Docker/Podman、SSH server、Hermes 和远程自动挂载未启用。
- Bash 配置与镜像列表和 standalone 一致。
- 软件按 store 输出路径核对；Home Manager 的 `hm-session-vars.sh` 是按宿主生成的配置产物，单独排除。

真实 NixOS-WSL 首次启动、用户登录和系统切换仍需在目标发行版验证。使用 `sudo nixos-rebuild switch --flake .#wsl` 同时激活系统与用户配置。
