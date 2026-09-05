# NixOS Home Manager entry without desktop configuration.
# Bare CLI packages are installed by profiles/cli.nix at system level.
{ ... }:

{
  imports = [ ./common.nix ];

  home = {
    username = "xuqihao";
    homeDirectory = "/home/xuqihao";
    stateVersion = "26.05";
  };
}
