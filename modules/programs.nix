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

    # --- 1. 基础工具 ---
    pkgs-stable.git
    pkgs-stable.wget
    pkgs-stable.vim
    pkgs-stable.tmux
    pkgs-stable.sshfs
    pkgs-stable.calcurse
    pkgs-stable.ffmpeg
    pkgs-stable.pandoc
    pkgs-stable.cmatrix
    pkgs-stable.fish
    pkgs-stable.oh-my-fish
    pkgs-stable.starship

    # --- 2. 文件管理 ---
    pkgs-stable.fd
    pkgs-stable.tree
    pkgs-stable.nnn
    pkgs-stable.dust
    pkgs-stable.lsd
    pkgs-stable.eza

    # --- 3. 系统监控 ---
    pkgs-stable.btop
    pkgs-stable.iftop
    pkgs-stable.iotop
    pkgs-stable.procs
    pkgs-stable.tcping-rs
    pkgs-stable.traceroute
    pkgs-stable.cpu-x

    # --- 4. 终端工具 ---
    pkgs-stable.bat
    pkgs-stable.glow
    pkgs-stable.chafa
    pkgs-stable.tealdeer

    # --- 5. 终端仿真器 ---
    pkgs-stable.kitty

    # --- 6. 办公软件 ---
    pkgs-stable.libreoffice
    pkgs-stable.thunderbird
    pkgs-stable.calibre
    pkgs-stable.zotero

    # --- 7. 媒体播放器 ---
    pkgs-stable.vlc
    pkgs-stable.mpv
    pkgs-stable.mpd
    pkgs-stable.amberol
    pkgs-stable.audacious
    pkgs-stable.psst # a spotify client written in rust
    pkgs-stable.cider # a apple music client

    # --- 8. 图像/视频处理 ---
    pkgs-stable.gimp
    pkgs-stable.inkscape
    pkgs-stable.krita
    pkgs-stable.pinta
    pkgs-stable.digikam
    pkgs-stable.darktable
    pkgs-stable.blender
    pkgs-stable.xnconvert
    pkgs-stable.p7zip

    # --- 9. 3D/工程软件 ---
    pkgs-stable.freecad
    pkgs-stable.librecad
    pkgs-stable.qcad
    pkgs-stable.openscad
    pkgs-stable.qgis

    # --- 10. 网络工具 ---
    pkgs-stable.wireguard-tools
    pkgs-stable.syncthing
    pkgs-stable.localsend
    pkgs-stable.qbittorrent
    pkgs-stable.aria2

    # --- 11. 开发工具 ---
    pkgs-stable.rstudio
    pkgs-stable.emacs

    # --- 12. C/C++ 工具链 ---
    pkgs-stable.gcc
    pkgs-stable.gnumake
    pkgs-stable.clang
    pkgs-stable.clang-tools
    pkgs-stable.cmake
    pkgs-stable.ninja
    pkgs-stable.gdb
    pkgs-stable.valgrind
    pkgs-stable.pkg-config

    # --- 13. Rust 工具链 ---
    pkgs-stable.rustc
    pkgs-stable.cargo

    # --- 14. Go 工具链 ---
    pkgs-stable.go
    pkgs-stable.go-tools
    pkgs-stable.gopls
    pkgs-stable.delve

    # --- 15. Node.js ---
    pkgs-stable.nodejs
    pkgs-stable.yarn2nix

    # --- 16. Python 环境（基础包）---
    pkgs-stable.python3
    pkgs-stable.ripgrep

    # --- 17. JetBrains IDEs（稳定版本）---
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

    # --- 18. 科学计算 ---
    pkgs-stable.root

    # ==================== Unstable packages (需要追新/AI相关) ====================

    # --- 1. 浏览器 ---
    firefox
    chromium
    google-chrome
    servo

    # --- 2. 编辑器（需要追新）---
    vscode
    zed-editor
    code-cursor
    neovim
    neovide
    helix

    # --- 3. AI 相关工具（必须追新）---
    claude-code
    codex
    gemini-cli
    opencode-desktop
    cherry-studio
    opencode

    # --- 4. Git 工具（现代化界面需要追新）---
    lazygit
    gitui # a modern git ui written in rust
    sd # a modern sed written in rust

    # --- 5. 排版工具（快速迭代中）---
    typst
    tinymist

    # --- 6. 系统信息工具 ---
    ipfetch
    fastfetch
    honeyfetch

    # --- 7. 现代化监控工具 ---
    zenith
    impala
    bluetui
    bandwhich
    wego

    # --- 8. 现代化文件管理器 ---
    tre-command
    yazi

    # --- 9. 下载工具（需要最新规则支持）---
    yt-dlp
    sftpman

    # --- 10. 现代化终端工具 ---
    zellij # a modern tmux written in rust

    # --- 11. 音乐播放器 ---
    kew # a music player in terminel
    go-musicfox
    ncmpcpp
    termusic # a music player in terminel written in rust

    # --- 12. 容器工具 ---
    distrobox

    # --- 13. 笔记/知识管理 ---
    # obsidian
    siyuan

    # --- 14. 开发工具（AI相关或需要最新特性）---
    nil

    # --- 15. 录屏截图工具 ---
    obs-studio
    grim
    satty
    flameshot
    snipaste

    # --- 16. 中文软件（需要最新版本）---
    qq
    wechat-uos
    qqmusic
    eudic
    wordbook
    goldendict-ng
    wpsoffice-cn
    onlyoffice-desktopeditors

    # --- 17. 代理工具（需要最新规则支持）---
    clash-verge-rev
    clash-nyanpasu
    sing-box
    v2rayn
    proxypin

    # --- 18. 远程工具 ---
    rustdesk-flutter
    anydesk

    # --- 19. 视频会议 ---
    zoom-us
    mattermost
    mattermost-desktop

    # --- 20. 影视/娱乐 ---
    bilibili-tui
    piliplus
    dialect

    # --- 21. 其他工具 ---
    copyq
    bottom
    uget
    howdy # 人脸识别软件
    readest

    # --- 22. Python AI/数据科学包（需要最新版本）---
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
