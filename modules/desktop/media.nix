# modules/desktop/media.nix
#
# 媒体与创作档：音频播放、图像/视频编辑、CAD/工程、录屏与娱乐客户端。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # --- 1. 媒体播放器 ---
    pkgs-stable.vlc
    # → mpv 已移至 packages/cli-dev.nix（共享）
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

    # 录屏（截图工具 grim/satty/flameshot 在 core.nix）
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
  ];
}
