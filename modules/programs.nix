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
    obsidian
    root
    btop
    cmatrix
    yazi
    fish
    tmux
    bat
    lsd
    eza
    nnn
    yazi
    qbittorrent
    p7zip 
    obs-studio
    ffmpeg
    pandoc
    mpv
    mpd
    vlc
    ncmpcpp
    amberol
    audacious
    krita
    gimp
    inkscape
    blender
    dialect
    thunderbird
    wireguard-tools
    syncthing
    #clashtui
    clash-verge-rev
    clash-nyanpasu
    eudic
    goldendict-ng
    cherry-studio
    wechat-uos
    qq
    wemeet
    psst # a spotify client written in rust
    cider # a apple music client
    zoom-us
    mattermost
    mattermost-desktop
    google-chrome
    #rustdesk
    wpsoffice-cn
    onlyoffice-desktopeditors
    libreoffice
    calibre
    zotero
    distrobox
    opencode

    (python3.withPackages (python-pkgs: with python-pkgs; [
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
    ]))
 ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
