# Same software list as standalone, installed system-wide on NixOS.
{ pkgs, pkgs-stable, pkgs-master, ... }:

{
  environment.systemPackages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable pkgs-master;
  };
}
