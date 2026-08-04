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
    autoStart = false;
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
    vscode
    zed-editor
    warp-terminal
    pkgs-stable.neovim
    pkgs-stable.neovide
    helix
    pkgs-stable.vim
    pkgs-stable.emacs

    # --- 3. 终端仿真器 ---
    pkgs-stable.kitty

    # --- 4. Shell 和终端工具 ---
    # Shell（需要追新）
    # → zellij 已移至 packages/cli-dev.nix（共享）

    # 稳定 Shell
    # → tmux 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.fish
    pkgs-stable.oh-my-fish
    pkgs-stable.starship

    # 终端工具（稳定）
    # → bat / glow / tealdeer 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.chafa

    # --- 5. 基础工具 ---
    pkgs-stable.git
    # → wget / sshfs / ffmpeg / pandoc / cmatrix 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.calcurse

    # Git 工具（现代化界面）
    # → lazygit / sd 已移至 packages/cli-dev.nix（共享）
    gitui

    # --- 6. 文件管理 ---
    # 现代文件管理器
    tre-command
    # → yazi 已移至 packages/cli-dev.nix（共享）

    # 稳定文件管理器
    # → fd / tree / dust / eza 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.nnn
    pkgs-stable.lsd

    # --- 7. 系统监控 ---
    # 现代监控工具
    zenith
    impala
    bluetui
    bandwhich
    wego
    # → bottom 已移至 packages/cli-dev.nix（共享）

    # 稳定监控工具
    # → btop / procs 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.iftop
    pkgs-stable.iotop
    pkgs-stable.tcping-rs
    pkgs-stable.traceroute
    pkgs-stable.cpu-x

    # --- 8. 系统信息工具 ---
    ipfetch
    fastfetch

    # --- 9. 网络工具 ---
    pkgs-stable.wireguard-tools
    pkgs-stable.syncthing
    pkgs-stable.localsend
    pkgs-stable.qbittorrent
    # → aria2 已移至 packages/cli-dev.nix（共享）

    # 下载工具（需要最新规则支持）
    # → yt-dlp 已移至 packages/cli-dev.nix（共享）
    sftpman

    # --- 10. 媒体播放器 ---
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
    pkgs-stable.unzip
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

    # --- 15. 开发工具链 ---
    # C/C++（稳定）
    # → gcc / gnumake / cmake / ninja / gdb / pkg-config 已移至 packages/cli-dev.nix（共享）
    # 注意：clang / clang-tools 只保留在此（NixOS 系统级）——cli-dev.nix 因 HM buildEnv
    #       bin/ld 冲突不能放 gcc+clang；系统级 environment.systemPackages 共存无冲突。
    pkgs-stable.clang
    pkgs-stable.clang-tools
    # → valgrind 已移至 packages/cli-dev.nix（共享）

    # Rust（稳定）
    # → rustc / cargo 已移至 packages/cli-dev.nix（共享）

    # Go（稳定）
    # → go / gopls / delve / go-tools 已移至 packages/cli-dev.nix（共享）

    # Node.js（稳定）
    # → nodejs / jq 已移至 packages/cli-dev.nix（共享）

    # 其他开发工具（稳定）
    pkgs-stable.rstudio
    # → nil 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.biome

    # --- 16. 搜索工具 ---
    # → ripgrep 已移至 packages/cli-dev.nix（共享）

    # --- 17. Python 环境 ---
    # → 已移至 packages/cli-dev.nix（NixOS 与 home/standalone-linux.nix 共享）

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
    # → root 已移至 packages/cli-dev.nix（共享）

    # --- 20. 排版工具 ---
    # → typst / tinymist / typstyle 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.texlivePackages.scheme-full

    # --- 21. 容器工具 ---
    distrobox
    bubblewrap

    # --- 22. 中文软件 ---
    pkgs-stable.qq
    # pkgs-stable.wechat  # fixed via nixpkgs overlay (AppImage, official Tencent URL)
    pkgs-stable.wemeet
    pkgs-stable.qqmusic
    # pkgs-stable.eudic  # download broken (TLS error)
    pkgs-stable.wordbook
    # pkgs-stable.goldendict-ng

    # --- 23. 代理工具 ---
    pkgs-stable.mihomo
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
  ]
  # 共享 CLI 开发工具（与 home/standalone-linux.nix 同源；系统级安装使 sudo 可见）
  # 平台专用包在 cli-dev.nix 内用 stdenv.isLinux 条件处理。
  ++ (import ../packages/cli-dev.nix { inherit pkgs pkgs-stable; });

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
