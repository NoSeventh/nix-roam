{ pkgs-stable, username, ... }:

let
  mountPoint = "/home/${username}/mnt/juno";
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

  # 3. 定义用户 systemd 服务
  systemd.user.services.sshfs-remote = {
    description = "SSHFS mount for lxlogin";
    # 网络就绪后再启动
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # 用户登录后自动启动
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "simple";
      # 挂载命令（使用你的 SSH 密钥，无需额外指定 IdentityFile）
      ExecStart = "${pkgs-stable.sshfs}/bin/sshfs ${remote} ${mountPoint} -o reconnect,ServerAliveInterval=15,idmap=user";
      ExecStop = "${pkgs-stable.fuse}/bin/fusermount -u ${mountPoint}";
      RemainAfterExit = true;
      # 确保目录存在（如果 tmpfiles 没来得及创建）
      ExecStartPre = "${pkgs-stable.coreutils}/bin/mkdir -p ${mountPoint}";
    };
  };
}
