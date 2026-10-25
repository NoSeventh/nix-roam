# modules/office/nixos.nix
#
# 办公档：开源办公套件、邮件/文献、笔记、日历、翻译、排版（texlive）、
# 即时通信与视频会议。
{ pkgs
, pkgs-stable
, ...
}:

{
  environment.systemPackages = (import ./packages.nix { inherit pkgs pkgs-stable; });
}
