# Shared media applications for NixOS and standalone Linux.
{ pkgs, pkgs-stable, ... }:
with pkgs;
[
  # --- 1. 媒体播放器 ---
  pkgs-stable.vlc
  pkgs-stable.mpd
  pkgs-stable.amberol
  pkgs-stable.audacious
  pkgs-stable.psst
  kew
  go-musicfox
  ncmpcpp
  termusic

  # --- 2. 图像/视频处理 ---
  pkgs-stable.gimp
  pkgs-stable.inkscape
  pkgs-stable.krita
  pkgs-stable.pinta
  pkgs-stable.digikam
  pkgs-stable.darktable
  pkgs-stable.blender

  # 录屏（截图在桌面基座 core）
  obs-studio

  # --- 3. 3D/工程软件 ---
  pkgs-stable.freecad
  pkgs-stable.librecad
  pkgs-stable.qcad
  pkgs-stable.openscad
  pkgs-stable.qgis

  # --- 4. 下载与娱乐 ---
  pkgs-stable.qbittorrent
  bilibili-tui
  piliplus
]
