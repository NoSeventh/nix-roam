# NixOS Home Manager entry without desktop configuration.
# Shared tools: profiles/cli.nix; NixOS runtimes: profiles/nixos-base.nix.
{ username, stateVersion, ... }:

{
  imports = [ ./common.nix ];

  home = {
    inherit username stateVersion;
    homeDirectory = "/home/${username}";
  };
}
