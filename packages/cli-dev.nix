# packages/cli-dev.nix
#
# 跨平台共享 CLI 开发工具列表 —— 纯函数，返回 package list。
# 单一事实源，被四处导入：
#   - profiles/cli.nix             → NixOS-WSL 的 environment.systemPackages
#   - modules/desktop/core.nix         → NixOS 的 environment.systemPackages（系统级、sudo 可见）
#   - home/standalone-linux.nix    → 非 NixOS Linux 的 home.packages（用户级）
#   - home/standalone-darwin.nix   → macOS 的 home.packages（用户级）
#
# 平台专用包用 stdenv.hostPlatform.isLinux / stdenv.hostPlatform.isDarwin 条件判断，不再需要单独的
# cli-dev-{linux,darwin}.nix 文件。
# 只放"无需 HM 托管 dotfile 的纯命令行工具"。
# 需要 dotfile 配置的（git/bash/starship/helix/ssh/nixvim/fastfetch）见 home/common.nix。
{ pkgs, pkgs-stable, ... }:

with pkgs; [
  # --- 现代基础 CLI ---
  # 与 modules/desktop/ 桌面档（core/dev/media 等）共享的工具统一走 stable（全局版本一致）；
  # 仅追新的小工具（sd / bottom / gh / lazygit）走 unstable。
  pkgs-stable.ripgrep
  pkgs-stable.fd
  sd
  pkgs-stable.dust
  pkgs-stable.procs
  bottom
  pkgs-stable.btop
  pkgs-stable.tree
  pkgs-stable.tre-command
  pkgs-stable.tealdeer
  pkgs-stable.glow
  pkgs-stable.bat
  gh
  lazygit

  # --- 文件 / 会话 ---
  pkgs-stable.nnn
  pkgs-stable.yazi
  pkgs-stable.eza
  zellij
  pkgs-stable.tmux
  pkgs-stable.mpv
  pkgs-stable.ffmpeg
  pkgs-stable.pandoc
  pkgs-stable.cmatrix
  pkgs-stable.sl
  pkgs-stable.asciiquarium
  pkgs-stable.oneko

  # --- 开发工具链（稳定通道） ---
  # 注意：只保留 gcc 作为 C/C++ 工具链。不要同时放 gcc + clang ——
  # 两者的 wrapper 都提供 bin/ld，在同一个 home-manager profile 的 buildEnv 里会
  # 产生路径冲突导致 build 失败。需要 clang 的机器请用原生包管理器安装，或在
  # NixOS 上经 modules/desktop/dev.nix（那里 gcc+clang 共存于 environment.systemPackages 不冲突）。
  pkgs-stable.gcc
  pkgs-stable.gnumake
  pkgs-stable.cmake
  pkgs-stable.ninja
  pkgs-stable.gdb
  pkgs-stable.pkg-config
  pkgs-stable.rustc
  pkgs-stable.cargo
  pkgs-stable.go
  pkgs-stable.gopls
  pkgs-stable.delve
  pkgs-stable.go-tools
  # Node/npm/pnpm and the Python scientific environment are NixOS-only
  # (profiles/nixos-base.nix). Standalone projects manage their own runtimes.
  pkgs-stable.uv
  pkgs-stable.jq
  opencode
  pi-coding-agent

  # --- 本仓库自有工具 ---
  # roam 统一 CLI（switch/status/doctor/rollback/gc/check/update/info，按宿主分发；
  # 实现见 packages/roam.sh；包内经 symlinkJoin 附 bash 补全文件，见 roam.nix）。
  # 放共享列表使四个安装点都有它；纯 bash + 各点本就有的环境工具，闭包无新增依赖。
  (pkgs.callPackage ./roam.nix { })

  # --- Nix 工具 ---
  # nh：roam switch 双侧重建前端（NixOS → nh os、standalone → nh home），四安装点
  # 同包保证各宿主行为一致（nom 已随 wrapper 进 PATH）。NixOS 侧原 programs.nh.enable
  # 已退役改由此列表单源（该模块除装包外无额外作用）。
  nh
  nil
  nixpkgs-fmt

  # --- 排版（便携 CLI） ---
  typst
  tinymist
  typstyle

  # --- AI 开发辅助 CLI ---
  codegraph
  rtk

  # --- 小众 / 网络 CLI ---
  yt-dlp
  pkgs-stable.sshfs
  pkgs-stable.wget
  pkgs-stable.curl
  pkgs-stable.aria2
] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
  # --- Linux-only 包 ---
  pkgs-stable.valgrind
  # C++ ROOT application; PyROOT is configured separately on NixOS.
  pkgs-stable.root
]
