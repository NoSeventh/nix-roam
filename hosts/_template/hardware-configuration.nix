# 占位硬件配置 —— 用前必读：
#   · bootstrap/nixos.sh install 链路会用 nixos-generate-config --root /mnt 的结果整体覆盖本文件；
#   · adopt 已有系统时，把目标机现有 /etc/nixos/hardware-configuration.nix 内容拷进来并提交；
#   · 直接手工使用时必须核对 fileSystems 设备与 UUID。
# 下面是安装器默认风格（按卷标挂载，全新安装分区后可打标签，或改成自己的 UUID）。
{ config, lib, pkgs, ... }:

{
  imports = [ ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  # swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];
}
