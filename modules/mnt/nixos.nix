{ config, lib, pkgs, pkgs-stable, username, ... }:

let
  mountPoint = "${config.users.users.${username}.home}/mnt/juno";
  # IHEP 集群账号（远程身份），与本地用户名无关，不随 username 单点定义联动
  remote = "xuqihao@lxlogin.ihep.ac.cn:/";
  # mount 由系统管理，但 SSH 使用登录用户的配置、密钥和 known_hosts。
  userSSH = pkgs.writeShellScript "juno-user-ssh" ''
    exec ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg username} -- \
      ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
      -o ConnectTimeout=10 "$@"
  '';
  # UID/GID 由运行时账户数据库解析，避免假设动态分配的本地 UID 为 1000。
  mountHelper = pkgs.writeShellScriptBin "mount.fuse.roam-sshfs" ''
    uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg username})"
    gid="$(${pkgs.coreutils}/bin/id -g ${lib.escapeShellArg username})"
    exec ${pkgs-stable.sshfs}/bin/sshfs "$@" \
      -o "uid=$uid,gid=$gid,allow_other,default_permissions,umask=0077,ssh_command=${userSSH}"
  '';
in
{
  # 1. 确保 sshfs 可用
  environment.systemPackages = [ pkgs-stable.sshfs ];
  system.fsPackages = [ mountHelper ];

  # 2. 创建挂载点目录（如果不存在）
  systemd.tmpfiles.rules = [
    "d ${mountPoint} 0755 ${username} users -"
  ];

  # 3. autofs 需要系统级权限。NixOS 按 Where 正确转义单元名；仅触发器随启动注册。
  systemd.mounts = [{
    description = "SSHFS mount for lxlogin";
    what = remote;
    where = mountPoint;
    type = "fuse.roam-sshfs";
    options = "_netdev,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3";
    mountConfig.TimeoutSec = "30s";
  }];
  systemd.automounts = [{
    description = "On-demand SSHFS automount for lxlogin";
    where = mountPoint;
    wantedBy = [ "multi-user.target" ];
    automountConfig.TimeoutIdleSec = "5min";
  }];
}
