# Home Manager implementation of the mnt layer on standalone Darwin.
{ config, lib, pkgs-stable, ... }:

let
  mountPoint = "${config.home.homeDirectory}/mnt/juno";
  remote = "xuqihao@lxlogin.ihep.ac.cn:/";
  mapFile = "${config.home.homeDirectory}/.config/nix-roam/auto_sshfs";
in
{
  home.activation.createMntMountPoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${mountPoint}
    chmod 0755 ${mountPoint}
  '';

  # macOS 原生 autofs map：登录时不连接，首次访问挂载点时由
  # macFUSE/SSHFS 触发。需要一次性注册到 /etc/auto_master（见 docs/roam.md）。
  home.file.".config/nix-roam/auto_sshfs".text = ''
    ${mountPoint} -fstype=sshfs,volname=juno,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 :sshfs#${remote}
  '';

  # 生成给用户执行的一次性刷新命令，不在 HM 激活中隐式请求 root。
  home.file.".config/nix-roam/enable-autofs-mnt" = {
    executable = true;
    text = ''
      #!/bin/sh
      set -eu
      map="${mapFile}"
      entry="/- $map"
      if ! sudo grep -Fqx "$entry" /etc/auto_master; then
        printf '%s\n' "$entry" | sudo tee -a /etc/auto_master >/dev/null
      fi
      sudo /usr/sbin/automount -vc
    '';
  };
}
