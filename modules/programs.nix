{ config, pkgs, ... }:

{
# Install firefox.
  programs.firefox.enable = true;

  programs.steam = {
  enable = true; # Master switch, already covered in installation
  remotePlay.openFirewall = true;  # Open ports in the firewall for Steam Remote Play
  dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
  # Other general flags if available can be set here.
};

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
    obs-studio
    ffmpeg
    pandoc
    mpv
    gimp
    inkscape
    blender
    thunderbird
    wireguard-tools
    syncthing
    clashtui
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
