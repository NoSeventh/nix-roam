# home/standalone.nix
#
# 非 NixOS 模式下的 Home Manager 入口（Linux / WSL / macOS 通用）。
# = common（便携 CLI 核心）+ 共享 CLI 工具（home.packages）。
# 零 GUI。home.username / homeDirectory / stateVersion 由 flake 的 mkStandaloneHome 注入。
{ config, pkgs, pkgs-stable, inputs, ... }:

{
  imports = [
    ./common.nix
  ];

  # 共享 CLI 开发工具（用户级安装；与 NixOS 的 programs.nix 同源）
  home.packages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable;
  };
}
