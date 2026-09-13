# NixOS Home Manager entry without desktop configuration.
# Shared tools: profiles/cli.nix; NixOS runtimes: profiles/nixos-base.nix.
{ ... }:

{
  imports = [ ./common.nix ];

  home = {
    username = "xuqihao";
    homeDirectory = "/home/xuqihao";
    stateVersion = "26.05";
  };
}
