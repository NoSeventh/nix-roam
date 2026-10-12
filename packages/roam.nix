# Package the Bash entry, command library, and lazy-loaded completion together.
# jq/nix/git/nh/home-manager are supplied by the shared CLI list or bootstrap.
{ pkgs }:
pkgs.symlinkJoin {
  name = "roam";
  paths = [
    (pkgs.writeShellApplication {
      name = "roam";
      text = ''
        ROAM_LIB_DIR=${./roam}
      '' + builtins.readFile ./roam.sh;
    })
    (pkgs.writeTextDir "share/bash-completion/completions/roam"
      (builtins.readFile ./roam-completion.bash))
  ];
}
