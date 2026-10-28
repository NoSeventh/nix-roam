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

  # 有用户 systemd manager 时，这个钩子只注册 automount；没有用户 bus 的 WSL
  # 则由 roam mnt start 自动降级为直接后台 SSHFS。
  programs.bash.initExtra = lib.mkAfter ''
    case $- in
      *i*) roam mnt start >/dev/null 2>&1 ;;
    esac
  '';

  # Home Manager 支持用户级 mount/automount unit。mount 不加入 default.target，
  # 因此 user manager 启动时只安装触发器，访问挂载点才会建立 SSHFS。
  systemd.user.mounts.sshfs-remote = {
    Unit = {
      Description = "SSHFS mount for lxlogin";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Mount = {
      What = remote;
      Where = mountPoint;
      Type = "fuse.sshfs";
      Options = "_netdev,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user";
      TimeoutSec = "30s";
    };
  };

  systemd.user.automounts.sshfs-remote = {
    Unit.Description = "On-demand SSHFS automount for lxlogin";
    Automount = {
      Where = mountPoint;
      TimeoutIdleSec = "5min";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
