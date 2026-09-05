# Shared NixOS foundation for desktop and WSL hosts.
{ ... }:

{
  imports = [
    ../modules/fix-network.nix
    ./locale.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "Asia/Shanghai";

  users.users.xuqihao = {
    isNormalUser = true;
    description = "xuqihao";
    extraGroups = [ "wheel" ];
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
    "pnpm-10.29.2"
  ];

  system.stateVersion = "26.05";
}
