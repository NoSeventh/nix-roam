{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    wget
    ipfetch
    fastfetch
    honeyfetch
    fd
    dust
    glow
    iftop
    iotop
    bandwhich
    chafa
    bat
    lsd
    eza
    tree
    tre-command
    yt-dlp
    ffmpeg
    pandoc
    distrobox
    wego
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
