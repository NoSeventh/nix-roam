{ config, pkgs, ... }:

{
  programs.firefox.enable = true;
  programs.chromium.enable = true;

  programs.steam = {
    enable = true; # Master switch, already covered in installation
    remotePlay.openFirewall = true;  # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
    # Other general flags if available can be set here.
  };

  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal.relayHosts = ["example.com"];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    lazygit
    delta
    starship
    kitty
    ipfetch
    fastfetch
    honeyfetch
    fd
    ripgrep
    dust
    cpu-x
    proxypin
    neovim
    neovide
    helix
    emacs
    vscode
    zed-editor
    siyuan
    obsidian
    glow
    root
    btop
    bottom
    zenith
    procs
    bandwhich
    aria2
    cmatrix
    yazi
    calcurse
    chafa
    fish
    oh-my-fish
    # zsh
    # oh-my-zsh
    tmux
    zellij # a modern tmux written in rust
    bat
    lsd
    eza
    tree
    tre-command
    nnn
    yazi
    qbittorrent
    yt-dlp
    p7zip
    obs-studio
    ffmpeg
    pandoc
    mpv
    mpd
    vlc
    kew # a music player in terminel
    termusic # a music player in terminel written in rust
    go-musicfox
    qqmusic
    ncmpcpp
    amberol
    audacious
    snipaste
    flameshot
    krita
    gimp
    inkscape
    digikam
    darktable
    blender
    # davinci-resolve
    dialect
    xnconvert
    uget
    thunderbird
    wireguard-tools
    syncthing
    #clashtui
    clash-verge-rev
    clash-nyanpasu
    sing-box
    v2rayn
    eudic
    wordbook
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
    # microsoft-edge
    servo
    rustdesk-flutter
    anydesk
    #todesk
    wpsoffice-cn
    onlyoffice-desktopeditors
    libreoffice
    calibre
    zotero
    distrobox
    opencode
    howdy # 人脸识别软件
    wego
    rstudio
    jetbrains-toolbox
    jetbrains.idea-oss
    jetbrains.idea
    jetbrains.clion
    jetbrains.rust-rover
    jetbrains.goland
    jetbrains.pycharm-oss
    jetbrains.pycharm
    jetbrains.ruby-mine
    jetbrains.rider
    jetbrains.mps
    jetbrains.datagrip
    jetbrains.webstorm
    jetbrains.phpstorm

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
