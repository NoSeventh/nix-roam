# Home Manager implementation of the mnt layer on standalone Darwin.
{ config, lib, pkgs-stable, ... }:

let
  mountPoint = "${config.home.homeDirectory}/mnt/juno";
  remote = "xuqihao@lxlogin.ihep.ac.cn:/";
in
{
  home.activation.createMntMountPoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${mountPoint}
    chmod 0755 ${mountPoint}
  '';

  launchd.agents.sshfs-remote = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs-stable.sshfs}/bin/sshfs"
        "-f"
        remote
        mountPoint
        "-o"
        "reconnect,ServerAliveInterval=15,ServerAliveCountMax=3"
      ];
      RunAtLoad = true;
      KeepAlive = {
        NetworkState = true;
      };
      ProcessType = "Interactive";
    };
  };
}
