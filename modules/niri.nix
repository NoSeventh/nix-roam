{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
{

  # imports = [
  #   inputs.dms.nixosModules.default
  # ];
  # niri设置
  programs.niri.enable = true;
  programs.hyprland.enable = true;
  programs.dms-shell = {
    enable = true;
    quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
    systemd.enable = true;
    enableSystemMonitoring = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableVPN = true;
  };

  environment.systemPackages = with pkgs; [
    fuzzel
    ghostty
    alacritty
    alacritty-theme
    bibata-cursors
    xwayland-satellite
    xsettingsd
    noctalia-shell
    dms-shell
    dsearch
    # inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    # inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };
}
