# packages/cli-dev.nix
#
# 共享 CLI 开发工具列表 —— 纯函数，返回 package list。
# 单一事实源，被两处导入：
#   - modules/programs.nix   → NixOS 的 environment.systemPackages（系统级、sudo 可见）
#   - home/standalone.nix    → 非 NixOS 的 home.packages（用户级）
#
# 只放"无需 HM 托管 dotfile 的纯命令行工具"。
# 需要 dotfile 配置的（git/bash/starship/helix/ssh/nixvim/fastfetch）见 home/common.nix。
{ pkgs, pkgs-stable, ... }:

with pkgs; [
  # --- 现代基础 CLI ---
  # 与 modules/programs.nix 共享的工具统一走 stable（全局版本一致）；
  # 仅追新的小工具（sd / bottom / gh / lazygit）走 unstable。
  pkgs-stable.ripgrep
  pkgs-stable.fd
  sd
  pkgs-stable.dust
  pkgs-stable.procs
  bottom
  pkgs-stable.btop
  pkgs-stable.tree
  pkgs-stable.tealdeer
  pkgs-stable.glow
  pkgs-stable.bat
  gh
  lazygit

  # --- 文件 / 会话 ---
  yazi
  pkgs-stable.eza
  zellij
  pkgs-stable.tmux

  # --- 开发工具链（稳定通道） ---
  # 注意：只保留 gcc 作为 C/C++ 工具链。不要同时放 gcc + clang ——
  # 两者的 wrapper 都提供 bin/ld，在同一个 home-manager profile 的 buildEnv 里会
  # 产生路径冲突导致 build 失败。需要 clang 的机器请用原生包管理器安装，或在
  # NixOS 上经 modules/programs.nix（那里 gcc+clang 共存于 environment.systemPackages 不冲突）。
  pkgs-stable.gcc
  pkgs-stable.gnumake
  pkgs-stable.cmake
  pkgs-stable.ninja
  pkgs-stable.gdb
  pkgs-stable.valgrind  # Linux-only（与 root 同；darwin 目标未实测）
  pkgs-stable.pkg-config
  pkgs-stable.rustc
  pkgs-stable.cargo
  pkgs-stable.go
  pkgs-stable.gopls
  pkgs-stable.delve
  pkgs-stable.go-tools
  pkgs-stable.nodejs
  bun
  pkgs-stable.jq
  pkgs-stable.root

  # --- Python 环境（NixOS modules/programs.nix 与 home/standalone.nix 共享） ---
  # 注意：bare python3 不单独放（会与 withPackages 的 python3-env 产生 buildEnv 冲突）；
  # root / rpy2 / torch 较重，且 root 是 Linux-only；standalone 目标为 macOS 需按平台裁剪。
  (python3.withPackages (
    python-pkgs: with python-pkgs; [
      pip
      jupyter
      pyyaml
      pandas
      numpy
      scipy
      sympy
      matplotlib
      root
      uproot
      requests
      rpy2
      torch
      uv
      pytest
    ]
  ))

  # --- Nix 工具 ---
  nil
  nixpkgs-fmt

  # --- 排版（便携 CLI） ---
  typst
  tinymist
  typstyle

  # --- 小众 / 网络 CLI ---
  yt-dlp
  pkgs-stable.sshfs
  pkgs-stable.wget
  pkgs-stable.curl
  pkgs-stable.aria2
]
