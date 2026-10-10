# modules/dev/home.nix — dev 层的 standalone 用户级实现
#
# 用户级子集，相对系统级 nixos.nix 的刻意裁剪（勿"补齐"）：
#   - 无 clang / clang-tools：HM buildEnv 下与 cli-dev.nix 的 gcc 冲突（bin/ld），
#     clang 只留在 NixOS 系统级（packages/cli-dev.nix 头注释同款规则）；
#   - 无 neovim：common.nix 的 nixvim 已在同一 profile 提供 bin/nvim，再入裸
#     neovim 会撞 buildEnv；neovide 是 GUI 前端（走 socket），无冲突；
#   - 无 helix：common.nix 的 programs.helix 已装；
#   - 无 mysql 服务 / distrobox / bubblewrap：需系统级支持，非用户级可迁移。
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  # 编辑器
  vscode
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
