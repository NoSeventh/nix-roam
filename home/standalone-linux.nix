# home/standalone-linux.nix
#
# 非 NixOS Linux 模式下的 Home Manager 入口（Linux / WSL 通用）。
# = common（便携 CLI 核心）+ 跨平台 CLI 工具 + Linux 专用 CLI 工具（home.packages）。
# 零 GUI。home.username / homeDirectory / stateVersion 由 flake 的 mkStandaloneHome 注入。
{ config, pkgs, pkgs-stable, pkgs-master, inputs, ... }:

{
  imports = [
    ./common.nix
    ./nix-cn.nix
  ];

  # 共享 CLI 开发工具（用户级安装；与 NixOS 的 programs.nix 同源）
  # 平台专用包在 cli-dev.nix 内用 stdenv.isLinux 条件处理。
  home.packages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable pkgs-master;
  };
}
