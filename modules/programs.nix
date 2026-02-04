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
    neovim
    helix
    vscode
    zed-editor
    siyuan
    root
    btop
    cmatrix
    obsidian
    yazi
    tmux
    bat
    lsd
    eza
    nnn
    yazi
    obs-studio
    ffmpeg
    pandoc
    mpv
    ncmpcpp
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
    calibre
    zotero
    distrobox
    (python3.withPackages (python-pkgs: with python-pkgs; [
      pip
      pyyaml
      pandas
      numpy
      scipy
      matplotlib
      root
      uproot
      requests
      rpy2
      torch
    ]))
 ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
