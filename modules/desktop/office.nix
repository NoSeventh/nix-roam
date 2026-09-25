# modules/desktop/office.nix
#
# 办公与中文软件档：办公套件、邮件/文献、笔记、日历、翻译、即时通信与视频会议。
# wechat overlay 必须与本档同行（overlay 只改 wechat 一个包，不 import 本档即不生效）。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # --- 1. 办公软件 ---
    pkgs-stable.libreoffice
    pkgs-stable.thunderbird
    pkgs-stable.calibre
    pkgs-stable.zotero

    # 中文办公软件（需要最新版本）
    wpsoffice-cn
    onlyoffice-desktopeditors

    # --- 2. 笔记/知识管理 ---
    siyuan

    # --- 3. 日历与翻译 ---
    pkgs-stable.calcurse
    dialect

    # --- 4. 中文软件 ---
    pkgs-stable.qq
    # pkgs-stable.wechat  # fixed via nixpkgs overlay (AppImage, official Tencent URL)
    pkgs-stable.wemeet
    pkgs-stable.qqmusic
    # pkgs-stable.eudic  # download broken (TLS error)
    pkgs-stable.wordbook
    # pkgs-stable.goldendict-ng

    # --- 5. 视频会议 ---
    pkgs-stable.zoom-us
    # pkgs-stable.mattermost
    pkgs-stable.mattermost-desktop
  ];

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
