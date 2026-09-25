# modules/desktop/dev.nix
#
# 开发档：编辑器全家、语言工具链、排版与容器工具，以及开发用服务（mysql）。
# 基础 CLI 工具链（gcc/rust/go/…）在 packages/cli-dev.nix，随 core.nix 走；
# 轻量主机不 import 本档即无编辑器与 texlive（多 GB 大件是砍档的主要重量来源）。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
  # --- 1. 开发服务（原 modules/desktop/services.nix）---
  services.mysql = {
    enable = true;
    package = pkgs-stable.mariadb;
  };

  # --- 2. 编辑器与工具 ---
  environment.systemPackages = with pkgs; [
    # 编辑器
    vscode
    zed-editor
    warp-terminal
    pkgs-stable.neovim
    pkgs-stable.neovide
    helix
    pkgs-stable.vim
    pkgs-stable.emacs

    # Git 工具（现代化界面）
    # → lazygit / sd 已移至 packages/cli-dev.nix（共享）
    gitui

    # C/C++（稳定）
    # → gcc / gnumake / cmake / ninja / gdb / pkg-config 已移至 packages/cli-dev.nix（共享）
    # 注意：clang / clang-tools 只保留在此（NixOS 系统级）——cli-dev.nix 因 HM buildEnv
    #       bin/ld 冲突不能放 gcc+clang；系统级 environment.systemPackages 共存无冲突。
    pkgs-stable.clang
    pkgs-stable.clang-tools
    # → valgrind 已移至 packages/cli-dev.nix（共享）

    # 其他开发工具（稳定）
    pkgs-stable.rstudio
    # → nil 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.biome

    # 排版（scheme-full 体积大，轻本首选砍除项）
    pkgs-stable.texlivePackages.scheme-full

    # 容器工具
    distrobox
    bubblewrap
  ];
}
