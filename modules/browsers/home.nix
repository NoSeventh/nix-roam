# modules/browsers/home.nix — browsers 层的 standalone 用户级实现
#
# 与系统级 nixos.nix 同包集（chrome/edge 走 pkgs-stable 的 unfree，standalone 实例
# 经 flake.nix 的 nixpkgsConfig 已 allowUnfree）。开源基座 firefox/chromium 属桌面
# 基座 core，不在可选层。
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  pkgs-stable.google-chrome
  pkgs-stable.microsoft-edge
  servo
]
