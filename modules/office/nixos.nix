# modules/office/nixos.nix
#
# 办公与中文软件档：办公套件、邮件/文献、笔记、日历、翻译、排版（texlive）、
# 即时通信与视频会议。
# wechat overlay 必须与本档同行（overlay 只改 wechat 一个包，不 import 本档即不生效）。
{ pkgs
, pkgs-stable
, ...
}:

{
  environment.systemPackages = (import ./packages.nix { inherit pkgs pkgs-stable; });

  # Fix wechat AppImage download: web.archive.org URL is dead, use official Tencent source
  nixpkgs.overlays = [
    (final: prev: {
      wechat = prev.wechat.overrideAttrs (old: {
        src = final.fetchurl {
          url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
          hash = "sha256-XxAvFnlljqurGPDgRr+DnuCKbdVvgXBPh02DLHY3Oz8=";
        };
      });
    })
  ];
}
