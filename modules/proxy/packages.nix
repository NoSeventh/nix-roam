# Shared proxy applications for NixOS and standalone Linux.
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
