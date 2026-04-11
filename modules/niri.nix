{
  config,
  pkgs,
  pkgs-stable,
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
  programs.sway.enable = true;
  programs.dms-shell = {
    enable = true;
    # quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
    systemd.enable = true;
    enableSystemMonitoring = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableVPN = true;
  };

  environment.systemPackages = with pkgs; [
    # ==================== Stable packages (不需要追新) ====================
    pkgs-stable.fuzzel
    pkgs-stable.ghostty
    pkgs-stable.alacritty
    pkgs-stable.wezterm
    pkgs-stable.alacritty-theme
    pkgs-stable.bibata-cursors
    pkgs-stable.xwayland-satellite
    pkgs-stable.xsettingsd

    # ==================== Unstable packages (需要追新) ====================
    # 自定义 shell（需要最新版本）
    quickshell
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
