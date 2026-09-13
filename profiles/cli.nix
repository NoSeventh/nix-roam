# Shared standalone tools; NixOS runtimes come from nixos-base.nix.
{ pkgs, pkgs-stable, pkgs-master, ... }:

{
  environment.systemPackages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable pkgs-master;
  };
}
