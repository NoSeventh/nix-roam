# Home Manager implementation of the mnt layer on standalone Linux.
{ config, lib, pkgs, pkgs-stable, ... }:

let
  mountPoint = "${config.home.homeDirectory}/mnt/juno";
  remote = "xuqihao@lxlogin.ihep.ac.cn:/";
in
{
  home.activation.createMntMountPoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${mountPoint}
    if ! ${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}; then
      chmod 0755 ${mountPoint}
    fi
  '';

  # Gentoo WSL may run systemd as PID 1 without starting a per-user manager.
  # Bash startup is the first reliable user-session hook in that environment.
  programs.bash.initExtra = lib.mkAfter ''
    case $- in
      *i*) roam mnt start >/dev/null 2>&1 ;;
    esac
  '';

  systemd.user.services.sshfs-remote = {
    Unit = {
      Description = "SSHFS mount for lxlogin";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs-stable.sshfs}/bin/sshfs -f ${remote} ${mountPoint} -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user";
      ExecStop = "${pkgs-stable.fuse}/bin/fusermount -u ${mountPoint}";
      ExecStartPre = "${pkgs-stable.coreutils}/bin/mkdir -p ${mountPoint}";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
