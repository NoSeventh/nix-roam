# WSL boot and integration are provided by NixOS-WSL, not PC hardware config.
{ ... }:

{
  imports = [
    ../../profiles/nixos-base.nix
    ../../profiles/cli.nix
  ];

  networking.hostName = "wsl";
  wsl = {
    enable = true;
    defaultUser = "xuqihao";
  };
}
