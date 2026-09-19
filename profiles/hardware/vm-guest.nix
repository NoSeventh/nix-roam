# 休眠硬件 profile：QEMU/KVM 虚拟机客户机（VM 内试用本仓库 / CI 调试用）。
# hosts/<hostname>/default.nix 显式 import 后才生效；未实机验证。
# virtio 块设备/网卡模块由 nixos-generate-config 生成的 hardware-configuration 覆盖，
# 这里只开 guest agent 与 SPICE 集成；非 SPICE 显示的 VM（VNC/物理直通）开着也无害。
{ ... }:

{
  services.qemuGuest.enable = true;
  # SPICE 显示协议下的剪贴板共享与动态分辨率
  services.spice-vdagentd.enable = true;
}
