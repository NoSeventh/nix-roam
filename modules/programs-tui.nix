{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    neovim
    neovide
    helix
    lazygit
    btop
    zenith
    impala
    bluetui
    procs
    cmatrix
    yazi
    calcurse
    tmux
    zellij # a modern tmux written in rust
    nnn
    yazi
    kew # a music player in terminel
    termusic # a music player in terminel written in rust
    go-musicfox
    ncmpcpp
    opencode
  ];
}
