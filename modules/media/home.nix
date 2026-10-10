# modules/media/home.nix — media 层的 standalone 用户级实现
#
# 与系统级 nixos.nix 同包集（全部是用户级 GUI/CLI 应用，WSLg / 普通 Linux 桌面可用）。
# mpd 仅装二进制不配服务（服务是系统域）；mpv/ffmpeg 在 cli-dev 基座。
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
  pkgs-stable.xnconvert

  # 录屏（截图在桌面基座 core）
  obs-studio
  snipaste

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
