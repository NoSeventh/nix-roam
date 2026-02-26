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
  ];
}
