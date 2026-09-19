# 休眠硬件 profile：Intel 核显（i915，Wayland 走 mesa 零配置）。
# hosts/<hostname>/default.nix 显式 import 后才生效；未实机验证。
{ pkgs, ... }:

{
  boot.initrd.kernelModules = [ "i915" ];

  # VA-API 硬解：Broadwell（5 代）及更新用 intel-media-driver，更老的核显换 intel-vaapi-driver
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
}
