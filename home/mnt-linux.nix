# Home Manager implementation of the mnt layer on standalone Linux.
{ config, lib, pkgs, ... }:

let
  mountPoint = "${config.home.homeDirectory}/mnt/juno";
in
{
  home.activation.createMntMountPoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${mountPoint}
    if ! ${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}; then
      chmod 0755 ${mountPoint}
    fi
  '';

  # 普通用户 manager 不支持 automount；standalone 使用锁保护的直接 SSHFS。
  programs.bash.initExtra = lib.mkAfter ''
    case $- in
      *i*) roam mnt start >/dev/null 2>&1 ;;
    esac
  '';
}
