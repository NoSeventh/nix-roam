# home/standalone-darwin.nix
#
# macOS 模式下的 Home Manager 入口。
# = common（便携 CLI 核心）+ 跨平台 CLI 工具 + macOS 专用 CLI 工具（home.packages）。
# 零 GUI。home.username / homeDirectory / stateVersion 由 flake 的 mkStandaloneHome 注入。
{ config, pkgs, pkgs-stable, pkgs-master, inputs, ... }:

{
  imports = [
    ./common.nix
    ./nix-cn.nix
  ];

  # 跨平台 CLI 开发工具（用户级安装）
  # 平台专用包在 cli-dev.nix 内用 stdenv.hostPlatform.isDarwin 条件处理。
  home.packages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable pkgs-master;
  };
}
