# Host-specific entry for the current NixOS workstation.
# Add sibling directories under hosts/ for additional machines.
{ ... }:

{
  imports = [
    ../../configuration.nix
    ./hardware-configuration.nix
  ];
}
