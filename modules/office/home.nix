# modules/office/home.nix — office 层的 standalone 用户级实现
#
# 与系统级 nixos.nix 同包集，除 wechat：其 AppImage 修复走 nixpkgs.overlays，
# 而 standalone HM 的 pkgs 由 flake 显式传入、nixpkgs.overlays 不生效——wechat
# 用户级暂缺（需要时在原生系统层安装）。texlive scheme-full 体积大（约 4GB），
# 仅在启用本层时进入闭包。
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  # --- 1. 办公软件 ---
  pkgs-stable.libreoffice
  pkgs-stable.thunderbird
  pkgs-stable.calibre
  pkgs-stable.zotero

  # 中文办公软件
  wpsoffice-cn
  onlyoffice-desktopeditors

  # --- 2. 笔记/知识管理 ---
  siyuan

  # --- 3. 日历与翻译 ---
  pkgs-stable.calcurse
  dialect

  # --- 4. 中文软件 ---
  pkgs-stable.qq
  pkgs-stable.wemeet
  pkgs-stable.qqmusic
  pkgs-stable.wordbook

  # --- 5. 视频会议 ---
  pkgs-stable.zoom-us
  pkgs-stable.mattermost-desktop

  # --- 6. 排版 ---
  pkgs-stable.texlivePackages.scheme-full
]
