{
  config,
  pkgs,
  pkgs-stable,
  pkgs-master,
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
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
    autoStart = true;
  };
  programs.nix-ld.enable = true;

  # environment.systemPackages = [
  #   inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  # ];

  environment.systemPackages = with pkgs; [
    # --- 1. 浏览器 ---
    pkgs-stable.firefox
    pkgs-stable.chromium
    pkgs-stable.google-chrome
    pkgs-stable.microsoft-edge
    servo

    # --- 2. 编辑器 ---
    # 现代编辑器（需要追新）
    vscode
    zed-editor
    code-cursor
    cursor-cli
    warp-terminal
    pkgs-stable.neovim
    pkgs-stable.neovide
    helix

    # 稳定编辑器
    pkgs-stable.vim
    pkgs-stable.emacs

    # --- 3. 终端仿真器 ---
    pkgs-stable.kitty

    # --- 4. Shell 和终端工具 ---
    # Shell（需要追新）
    zellij

    # 稳定 Shell
    pkgs-stable.tmux
    pkgs-stable.fish
    pkgs-stable.oh-my-fish
    pkgs-stable.starship

    # 终端工具（稳定）
    pkgs-stable.bat
    pkgs-stable.glow
    pkgs-stable.chafa
    pkgs-stable.tealdeer

    # --- 5. 基础工具 ---
    pkgs-stable.git
    pkgs-stable.wget
    pkgs-stable.sshfs
    pkgs-stable.calcurse
    pkgs-stable.ffmpeg
    pkgs-stable.pandoc
    pkgs-stable.cmatrix

    # Git 工具（现代化界面）
    lazygit
    gitui
    sd

    # --- 6. 文件管理 ---
    # 现代文件管理器
    tre-command
    yazi

    # 稳定文件管理器
    pkgs-stable.fd
    pkgs-stable.tree
    pkgs-stable.nnn
    pkgs-stable.dust
    pkgs-stable.lsd
    pkgs-stable.eza

    # --- 7. 系统监控 ---
    # 现代监控工具
    zenith
    impala
    bluetui
    bandwhich
    wego
    bottom

    # 稳定监控工具
    pkgs-stable.btop
    pkgs-stable.iftop
    pkgs-stable.iotop
    pkgs-stable.procs
    pkgs-stable.tcping-rs
    pkgs-stable.traceroute
    pkgs-stable.cpu-x

    # --- 8. 系统信息工具 ---
    ipfetch
    fastfetch
    honeyfetch

    # --- 9. 网络工具 ---
    pkgs-stable.wireguard-tools
    pkgs-stable.syncthing
    pkgs-stable.localsend
    pkgs-stable.qbittorrent
    pkgs-stable.aria2

    # 下载工具（需要最新规则支持）
    yt-dlp
    sftpman

    # --- 10. 媒体播放器 ---
    # 稳定播放器
    pkgs-stable.vlc
    pkgs-stable.mpv
    pkgs-stable.mpd
    pkgs-stable.amberol
    pkgs-stable.audacious
    pkgs-stable.psst
    # pkgs-stable.cider  # broken in nixpkgs 26.05

    # 终端音乐播放器
    kew
    go-musicfox
    ncmpcpp
    termusic

    # --- 11. 图像/视频处理 ---
    pkgs-stable.gimp
    pkgs-stable.inkscape
    pkgs-stable.krita
    pkgs-stable.pinta
    pkgs-stable.digikam
    pkgs-stable.darktable
    pkgs-stable.blender
    pkgs-stable.xnconvert
    pkgs-stable.p7zip
    pkgs-stable.poppler-utils

    # 录屏截图工具
    obs-studio
    grim
    satty
    flameshot
    snipaste

    # --- 12. 3D/工程软件 ---
    pkgs-stable.freecad
    pkgs-stable.librecad
    pkgs-stable.qcad
    pkgs-stable.openscad
    pkgs-stable.qgis

    # --- 13. 办公软件 ---
    # 稳定办公软件
    pkgs-stable.libreoffice
    pkgs-stable.thunderbird
    pkgs-stable.calibre
    pkgs-stable.zotero

    # 中文办公软件（需要最新版本）
    wpsoffice-cn
    onlyoffice-desktopeditors

    # --- 14. 笔记/知识管理 ---
    siyuan

    # --- 15. AI 相关工具 ---
    claude-code
    codex
    github-copilot-cli
    # antigravity
    # crush
    opencode
    opencode-desktop
    cherry-studio
    chatbox
    sillytavern
    # lmstudio

    # --- 16. 开发工具链 ---
    # C/C++（稳定）
    pkgs-stable.gcc
    pkgs-stable.gnumake
    pkgs-stable.clang
    pkgs-stable.clang-tools
    pkgs-stable.cmake
    pkgs-stable.ninja
    pkgs-stable.gdb
    pkgs-stable.valgrind
    pkgs-stable.pkg-config

    # Rust（稳定）
    pkgs-stable.rustc
    pkgs-stable.cargo

    # Go（稳定）
    pkgs-stable.go
    pkgs-stable.go-tools
    pkgs-stable.gopls
    pkgs-stable.delve

    # Node.js（稳定）
    pkgs-stable.nodejs

    # 其他开发工具（稳定）
    pkgs-stable.rstudio
    nil
    pkgs-stable.biome

    # --- 17. Python 环境 ---
    pkgs-stable.python3
    pkgs-stable.ripgrep

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
        uv
      ]
    ))

    # --- 18. JetBrains IDEs ---
    # pkgs-stable.jetbrains-toolbox
    # pkgs-stable.jetbrains.idea-oss
    # pkgs-stable.jetbrains.idea
    # pkgs-stable.jetbrains.clion
    # pkgs-stable.jetbrains.rust-rover
    # pkgs-stable.jetbrains.goland
    # pkgs-stable.jetbrains.pycharm-oss
    # pkgs-stable.jetbrains.pycharm
    # pkgs-stable.jetbrains.ruby-mine
    # pkgs-stable.jetbrains.rider
    # pkgs-stable.jetbrains.mps
    # pkgs-stable.jetbrains.datagrip
    # pkgs-stable.jetbrains.webstorm
    # pkgs-stable.jetbrains.phpstorm

    # --- 19. 科学计算 ---
    pkgs-stable.root

    # --- 20. 排版工具 ---
    typst
    tinymist
    typstyle
    pkgs-stable.texlivePackages.scheme-full

    # --- 21. 容器工具 ---
    distrobox
    bubblewrap

    # --- 22. 中文软件 ---
    pkgs-stable.qq
    pkgs-stable.wechat  # fixed via nixpkgs overlay (AppImage, official Tencent URL)
    pkgs-stable.wemeet
    pkgs-stable.qqmusic
    # pkgs-stable.eudic  # download broken (TLS error)
    pkgs-stable.wordbook
    # pkgs-stable.goldendict-ng

    # --- 23. 代理工具 ---
    pkgs-stable.clash-verge-rev
    pkgs-stable.clash-nyanpasu
    pkgs-stable.sing-box
    pkgs-stable.v2rayn
    pkgs-stable.proxypin

    # --- 24. 远程工具 ---
    pkgs-stable.rustdesk-flutter
    pkgs-stable.anydesk

    # --- 25. 视频会议 ---
    pkgs-stable.zoom-us
    # pkgs-stable.mattermost
    pkgs-stable.mattermost-desktop

    # --- 26. 影视/娱乐 ---
    bilibili-tui
    piliplus
    dialect

    # --- 27. 其他工具 ---
    pkgs-stable.copyq
    pkgs-stable.uget
    howdy
    pkgs-stable.readest
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
