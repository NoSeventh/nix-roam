# Shared office applications for NixOS and standalone Linux.
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  # --- 1. 办公软件 ---
  pkgs-stable.libreoffice
  pkgs-stable.thunderbird
  pkgs-stable.calibre
  pkgs-stable.zotero

  # 中文办公软件
  onlyoffice-desktopeditors

  # --- 2. 笔记/知识管理 ---
  siyuan

  # --- 3. 日历与翻译 ---
  pkgs-stable.calcurse
  dialect

  # --- 4. 中文软件 ---
  pkgs-stable.wordbook

  # --- 5. 视频会议 ---
  pkgs-stable.mattermost-desktop

  # --- 6. 排版 ---
  pkgs-stable.texlivePackages.scheme-full
]
