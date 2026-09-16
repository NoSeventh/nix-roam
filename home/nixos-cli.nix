# NixOS Home Manager entry without desktop configuration.
# Shared tools: profiles/cli.nix; NixOS runtimes: profiles/nixos-base.nix.
{ username, ... }:

{
  imports = [ ./common.nix ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";
  };
}
