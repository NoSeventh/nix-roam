# modules/proxy/home.nix — proxy 层的 standalone 用户级实现
#
# 仅客户端与内核二进制。tun/service 模式（programs.clash-verge 的 serviceMode/
# tunMode）需要 root 与系统服务，只留在 NixOS 系统级；用户级自行在客户端内配置。
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  pkgs-stable.mihomo
  pkgs-stable.clash-verge-rev
  pkgs-stable.clash-nyanpasu
  pkgs-stable.sing-box
  pkgs-stable.v2rayn
  pkgs-stable.proxypin
]
