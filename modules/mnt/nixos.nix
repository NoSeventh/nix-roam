{ pkgs-stable, username, ... }:

let
  mountPoint = "/home/${username}/mnt/juno";
  mountUnit = "home-${username}-mnt-juno";
  # IHEP 集群账号（远程身份），与本地用户名无关，不随 username 单点定义联动
  remote = "xuqihao@lxlogin.ihep.ac.cn:/";
in
{
  # 1. 确保 sshfs 可用
  environment.systemPackages = [ pkgs-stable.sshfs ];

  # 2. 创建挂载点目录（如果不存在）
  systemd.tmpfiles.rules = [
    "d ${mountPoint} 0755 ${username} users -"
  ];

  # 3. 用户级 systemd automount：登录时只注册触发器，访问挂载点时才连接 SSHFS。
  # NixOS 没有 systemd.user.mounts/automounts 高层选项，因此使用受支持的
  # systemd.user.units 原始 unit 定义；mount 单元不加入 default.target。
  systemd.user.units = {
    "${mountUnit}.mount".text = ''
      [Unit]
      Description=SSHFS mount for lxlogin
      After=network-online.target
      Wants=network-online.target

      [Mount]
      What=${remote}
      Where=${mountPoint}
      Type=fuse.sshfs
      Options=_netdev,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user
      TimeoutSec=30s
    '';

    "${mountUnit}.automount" = {
      wantedBy = [ "default.target" ];
      text = ''
        [Unit]
        Description=On-demand SSHFS automount for lxlogin

        [Automount]
        Where=${mountPoint}
        TimeoutIdleSec=5min
      '';
    };
  };
}
