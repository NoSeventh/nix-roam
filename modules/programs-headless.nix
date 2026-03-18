{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    lazygit
    gitui # a modern git ui written in rust
    sd # a modern sed written in rust
    wget
    vim
    neovim
    neovide
    helix
    typst
    tinymist
    fd
    ipfetch
    fastfetch
    honeyfetch
    btop
    iftop
    iotop
    zenith
    impala
    bluetui
    dust
    bandwhich
    wego
    procs
    glow
    chafa
    bat
    lsd
    eza
    tree
    tre-command
    cmatrix
    fish
    oh-my-fish
    # zsh
    # oh-my-zsh
    sshfs
    calcurse
    tmux
    zellij # a modern tmux written in rust
    tealdeer # a modern man written in rust
    nnn
    yazi
    yt-dlp
    ffmpeg
    kew # a music player in terminel
    termusic # a music player in terminel written in rust
    go-musicfox
    ncmpcpp
    pandoc
    root
    distrobox
    opencode
    # c/c++工具链
    gcc
    gnumake
    clang
    clang-tools
    cmake
    ninja
    gdb
    valgrind
    pkg-config
    # rust工具链
    rustc
    cargo
    # go工具链
    go
    go-tools
    gopls
    delve
    # node.js
    nodejs
    yarn2nix
  ];
}
