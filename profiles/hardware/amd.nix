# 休眠硬件 profile：AMD GPU / APU（RADV/mesa 开源栈，Wayland 零配置可用）。
# hosts/<hostname>/default.nix 显式 import 后才生效；未实机验证。
# mesa 用户态由 profiles/desktop.nix 的 hardware.graphics 提供；本 profile 只加 early KMS，
# 让显示管线在 initrd 就绪（换分辨率/无闪屏），纯 CLI 主机 import 也无害。
{ ... }:

{
  boot.initrd.kernelModules = [ "amdgpu" ];

  # VA-API 硬解走 mesa 自带；如需 AMD 专有 Vulkan（amdvlk）再取消注释：
  # hardware.graphics.extraPackages = [ pkgs.amdvlk ];
}
