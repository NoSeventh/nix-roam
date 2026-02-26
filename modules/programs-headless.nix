{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    lazygit
    wget
    vim
    neovim
    neovide
    helix
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
    yazi
    calcurse
    tmux
    zellij # a modern tmux written in rust
    nnn
    yazi
    yt-dlp
    ffmpeg
    kew # a music player in terminel
    termusic # a music player in terminel written in rust
    go-musicfox
    ncmpcpp
    pandoc
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
  ];
}
