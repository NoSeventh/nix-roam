# Shared NixOS foundation for desktop and WSL hosts.
{ pkgs-stable, ... }:

{
  imports = [
    ../modules/fix-network.nix
    ./locale.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "Asia/Shanghai";

  # --- 1. NixOS development runtimes (desktop and WSL) ---
  # Standalone hosts use native/project runtime management instead.
  environment.systemPackages = with pkgs-stable; [
    nodejs
    pnpm
    R
    # The C++ ROOT application comes from packages/cli-dev.nix.
    # Keep Python and ROOT bindings in the same package set / Python ABI.
    ((python3.withPackages (ps: with ps; [
      pip
      jupyter
      pyyaml
      pandas
      polars
      numpy
      scipy
      sympy
      matplotlib
      requests
      pytest
      root # PyROOT bindings from the Python package set.
      uproot
      rpy2
      torch
    ])).override {
      # rpy2 needs R at runtime, not only in its build environment.
      makeWrapperArgs = [ "--set" "R_HOME" "${pkgs-stable.R}/lib/R" ];
    })
  ];

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
