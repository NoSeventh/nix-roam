{
  config,
  pkgs,
  inputs,
  ...
}:

{
  programs.firefox = {
    enable = true;
  };
  programs.chromium = {
    enable = true;
  };
  programs.steam = {
    enable = true; # Master switch, already covered in installation
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
    # Other general flags if available can be set here.
  };

  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal.relayHosts = [ "example.com" ];
  };

  # environment.systemPackages = [
  #   inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  # ];

  environment.systemPackages = with pkgs; [
    starship
    kitty
    ripgrep
    cpu-x
    proxypin
    emacs
    vscode
    zed-editor
    code-cursor
    claude-code
    codex
    siyuan
    obsidian
    typst
    bottom
    aria2
    qbittorrent
    p7zip
    obs-studio
    mpv
    mpd
    vlc
    qqmusic
    amberol
    audacious
    snipaste
    grim
    satty
    flameshot
    pinta
    krita
    gimp
    inkscape
    digikam
    darktable
    blender
    freecad
    librecad
    qcad
    openscad
    qgis
    # davinci-resolve
    dialect
    xnconvert
    uget
    thunderbird
    wireguard-tools
    syncthing
    localsend
    # clashtui
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
    electron
    nil
    google-chrome
    # microsoft-edge
    servo
    rustdesk-flutter
    anydesk
    # todesk
    wpsoffice-cn
    onlyoffice-desktopeditors
    libreoffice
    calibre
    readest
    zotero
    howdy # 人脸识别软件
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

    (python3.withPackages (
      python-pkgs: with python-pkgs; [
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
      ]
    ))

  ];
}
