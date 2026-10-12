# modules/dev/nixos.nix
#
# 开发档：编辑器全家、语言工具链与容器工具，以及开发用服务（mysql）。
# 基础 CLI 工具链（gcc/rust/go/…）在 packages/cli-dev.nix，随 core.nix 走；
# 轻量主机不 import 本档即无编辑器与系统级 clang（排版 texlive 在 office.nix）。
{ pkgs
, pkgs-stable
, ...
}:

{
  # --- 1. 开发服务（原 modules/desktop/services.nix）---
  services.mysql = {
    enable = true;
    package = pkgs-stable.mariadb;
  };

  # --- 2. 编辑器与工具 ---
  environment.systemPackages = (import ./packages.nix { inherit pkgs pkgs-stable; }) ++ (with pkgs; [
    pkgs-stable.neovim
    helix
    pkgs-stable.clang
    pkgs-stable.clang-tools
    distrobox
  ]);
}
