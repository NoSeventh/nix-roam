{ config, pkgs, ... }:

{
# Install firefox.
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    starship
    kitty
    fastfetch
    helix
    vscode
    zed-editor
    siyuan
    root
    btop
    cmatrix
    obsidian
    yazi
    bat
    lsd
    eza
    nnn
    yazi
   # obs-studio
    ffmpeg
    mpv
    wireguard-tools
    syncthing
    clash-verge-rev
    wechat-uos
    qq
    wemeet
    zoom-us
    google-chrome
    #rustdesk
    wpsoffice-cn
    onlyoffice-desktopeditors
    libreoffice
    distrobox
 ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
