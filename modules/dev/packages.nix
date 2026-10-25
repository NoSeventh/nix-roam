# Shared dev applications for NixOS and standalone Linux.
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  # 编辑器
  zed-editor
  warp-terminal
  pkgs-stable.neovide
  pkgs-stable.vim
  pkgs-stable.emacs

  # Git 工具
  gitui

  # 其他开发工具
  pkgs-stable.rstudio
  pkgs-stable.biome
]
