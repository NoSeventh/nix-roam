{ config, pkgs, inputs, lib, ... }: {
  # imports = [
  #   inputs.dms.nixosModules.default
  # ];
  # programs.dms-shell = {
  #   enable = true;
  #   quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
  #   systemd.enable = true;
  #   enableSystemMonitoring = true;
  #   enableDynamicTheming = true;
  #   enableAudioWavelength = true;
  #   enableVPN = true;
  # };
  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    # inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default
    # noctalia-shell
    # ... 可能还有其他软件包
  ];
}
