{ config, pkgs, ... }:

{

# niri设置
programs.niri.enable = true;

environment.systemPackages = with pkgs; [
   # fuzzel
   alacritty
   bibata-cursors
   xwayland-satellite
  ];

environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };
}
