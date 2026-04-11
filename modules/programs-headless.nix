{ config, pkgs, pkgs-stable, ... }:
{
  environment.systemPackages = with pkgs; [
    # ==================== Stable packages (不需要追新) ====================
    # 基础工具
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

    # 文件管理
    pkgs-stable.fd
    pkgs-stable.tree
    pkgs-stable.nnn
    pkgs-stable.dust
    pkgs-stable.lsd
    pkgs-stable.eza

    # 系统监控
    pkgs-stable.btop
    pkgs-stable.iftop
    pkgs-stable.iotop
    pkgs-stable.procs

    # 终端工具
    pkgs-stable.bat
    pkgs-stable.glow
    pkgs-stable.chafa
    pkgs-stable.tealdeer # a modern man written in rust

    # 音乐播放器
    pkgs-stable.kew # a music player in terminel
    pkgs-stable.go-musicfox
    pkgs-stable.ncmpcpp

    # C/C++ 工具链
    pkgs-stable.gcc
    pkgs-stable.gnumake
    pkgs-stable.clang
    pkgs-stable.clang-tools
    pkgs-stable.cmake
    pkgs-stable.ninja
    pkgs-stable.gdb
    pkgs-stable.valgrind
    pkgs-stable.pkg-config

    # Rust 工具链
    pkgs-stable.rustc
    pkgs-stable.cargo

    # Go 工具链
    pkgs-stable.go
    pkgs-stable.go-tools
    pkgs-stable.gopls
    pkgs-stable.delve

    # Node.js
    pkgs-stable.nodejs
    pkgs-stable.yarn2nix

    # ==================== Unstable packages (需要追新/AI相关) ====================
    # Git 工具（现代化界面需要追新）
    lazygit
    gitui # a modern git ui written in rust
    sd # a modern sed written in rust

    # 编辑器（需要追新）
    neovim
    neovide
    helix

    # 排版工具（快速迭代中）
    typst
    tinymist

    # 系统信息工具
    ipfetch
    fastfetch
    honeyfetch

    # 现代化监控工具
    zenith
    impala
    bluetui
    bandwhich
    wego

    # 现代化文件管理器
    tre-command
    yazi

    # 下载工具（需要最新规则支持）
    yt-dlp
    sftpman

    # 现代化终端工具
    zellij # a modern tmux written in rust
    termusic # a music player in terminel written in rust

    # AI 相关工具
    opencode

    # 容器工具
    distrobox

    # 科学计算
    root
  ];
}
