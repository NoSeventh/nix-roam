{
  config,
  pkgs,
  pkgs-stable,
  inputs,
  ...
}:

{
  programs.firefox = {
    enable = true;
  };
  programs.chromium = {
    enable = true;
  };
  programs.steam = {
    enable = true; # Master switch, already covered in installation
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
    # Other general flags if available can be set here.
  };
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal.relayHosts = [ "example.com" ];
  };

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  # environment.systemPackages = [
  #   inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  # ];

  environment.systemPackages = with pkgs; [
    # ==================== Stable packages (不需要追新) ====================
    pkgs-stable.starship
    pkgs-stable.kitty
    pkgs-stable.ripgrep
    pkgs-stable.cpu-x
    pkgs-stable.traceroute
    pkgs-stable.tcping-rs

    # 办公软件
    pkgs-stable.libreoffice
    pkgs-stable.thunderbird
    pkgs-stable.calibre
    pkgs-stable.zotero

    # 媒体播放器
    pkgs-stable.vlc
    pkgs-stable.mpv
    pkgs-stable.mpd
    pkgs-stable.amberol
    pkgs-stable.audacious
    pkgs-stable.psst # a spotify client written in rust
    pkgs-stable.cider # a apple music client

    # 图像/视频处理
    pkgs-stable.gimp
    pkgs-stable.inkscape
    pkgs-stable.krita
    pkgs-stable.pinta
    pkgs-stable.digikam
    pkgs-stable.darktable
    pkgs-stable.blender
    pkgs-stable.xnconvert
    pkgs-stable.p7zip

    # 3D/工程软件
    pkgs-stable.freecad
    pkgs-stable.librecad
    pkgs-stable.qcad
    pkgs-stable.openscad
    pkgs-stable.qgis

    # 网络工具
    pkgs-stable.wireguard-tools
    pkgs-stable.syncthing
    pkgs-stable.localsend
    pkgs-stable.qbittorrent
    pkgs-stable.aria2

    # 开发工具
    pkgs-stable.rstudio
    pkgs-stable.emacs

    # Python 环境（基础包）
    pkgs-stable.python3

    # JetBrains IDEs（稳定版本）
    pkgs-stable.jetbrains-toolbox
    pkgs-stable.jetbrains.idea-oss
    pkgs-stable.jetbrains.idea
    pkgs-stable.jetbrains.clion
    pkgs-stable.jetbrains.rust-rover
    pkgs-stable.jetbrains.goland
    pkgs-stable.jetbrains.pycharm-oss
    pkgs-stable.jetbrains.pycharm
    pkgs-stable.jetbrains.ruby-mine
    pkgs-stable.jetbrains.rider
    pkgs-stable.jetbrains.mps
    pkgs-stable.jetbrains.datagrip
    pkgs-stable.jetbrains.webstorm
    pkgs-stable.jetbrains.phpstorm

    # ==================== Unstable packages (需要追新/AI相关) ====================
    # 浏览器
    firefox
    chromium
    google-chrome
    servo

    # 编辑器（需要追新）
    vscode
    zed-editor
    code-cursor
    neovide
    helix

    # AI 相关工具（必须追新）
    claude-code
    codex
    gemini-cli
    opencode-desktop
    cherry-studio

    # 笔记/知识管理
    obsidian
    siyuan

    # 开发工具（AI相关或需要最新特性）
    nil

    # 录屏截图工具
    obs-studio
    grim
    satty
    flameshot
    snipaste

    # 中文软件（需要最新版本）
    qq
    wechat-uos
    qqmusic
    eudic
    wordbook
    goldendict-ng
    wpsoffice-cn
    onlyoffice-desktopeditors

    # 代理工具（需要最新规则支持）
    clash-verge-rev
    clash-nyanpasu
    sing-box
    v2rayn
    proxypin

    # 远程工具
    rustdesk-flutter
    anydesk

    # 视频会议
    zoom-us
    mattermost
    mattermost-desktop

    # 影视/娱乐
    bilibili-tui
    piliplus
    dialect

    # 其他工具
    copyq
    bottom
    uget
    howdy # 人脸识别软件
    readest

    # Python AI/数据科学包（需要最新版本）
    (python3.withPackages (
      python-pkgs: with python-pkgs; [
        pip
        jupyter
        pyyaml
        pandas
        numpy
        scipy
        sympy
        matplotlib
        root
        uproot
        requests
        rpy2
        torch
      ]
    ))
  ];
}
