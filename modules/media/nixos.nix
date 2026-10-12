# modules/media/nixos.nix
#
# 媒体与创作档：音频播放、图像/视频编辑、CAD/工程、录屏与娱乐客户端。
{ pkgs
, pkgs-stable
, ...
}:

{
  environment.systemPackages = (import ./packages.nix { inherit pkgs pkgs-stable; });
}
