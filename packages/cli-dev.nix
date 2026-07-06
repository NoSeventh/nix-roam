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
  ripgrep
  fd
  sd
  dust
  procs
  bottom
  btop
  tree
  tealdeer
  glow
  gh
  lazygit

  # --- 文件 / 会话 ---
  yazi
  eza
  zellij
  tmux

  # --- 开发工具链（稳定通道） ---
  pkgs-stable.gcc
  pkgs-stable.gnumake
  pkgs-stable.cmake
  pkgs-stable.ninja
  pkgs-stable.clang
  pkgs-stable.clang-tools
  pkgs-stable.gdb
  pkgs-stable.pkg-config
  pkgs-stable.rustc
  pkgs-stable.cargo
  pkgs-stable.go
  pkgs-stable.gopls
  pkgs-stable.delve
  pkgs-stable.nodejs
  pkgs-stable.jq
  pkgs-stable.python3

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
