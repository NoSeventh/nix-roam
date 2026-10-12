# Shared browsers applications for NixOS and standalone Linux.
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  pkgs-stable.google-chrome
  pkgs-stable.microsoft-edge
  servo
]
