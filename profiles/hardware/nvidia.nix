# 休眠硬件 profile：NVIDIA GPU（含混合显卡 prime offload）。
# hosts/<hostname>/default.nix 显式 import 后才生效；hosts/nixos 当前用默认 mesa 驱动，未接线。
# 未在任何实机验证过，首台 NVIDIA 机器上手时按 AGENTS.md 验证纪律确认。
{ config, lib, vars, ... }:

let
  # 可选的混合显卡 BusID（hosts/<hostname>/variables.nix 的 gpuBusIDs）：
  # 未提供 → 纯 NVIDIA 配置（无 prime 块）；提供 nvidia+intel 或 nvidia+amdgpu → offload 模式。
  ids = vars.gpuBusIDs or { };
  iBus =
    if ids ? intel then { intelBusId = ids.intel; }
    else if ids ? amdgpu then { amdgpuBusId = ids.amdgpu; }
    else { };
in
{
  services.xserver.videoDrivers = [ "nvidia" ];

  # Wayland（niri）必须开 modesetting
  hardware.nvidia = {
    modesetting.enable = true;

    # 电源管理：笔记本合盖休眠唤醒建议开启；finegrained 仅 offload 模式下有意义，
    # 部分机型有唤醒问题，遇到再开。
    powerManagement.enable = true;
    # powerManagement.finegrained = true;

    # Turing（RTX 20 系）及更新的卡用 open 内核模块；GTX 16/10 系及更老改 false。
    open = true;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # package = config.boot.kernelPackages.nvidiaPackages.beta;  # 需要新驱动时

    prime = lib.mkIf (ids ? nvidia) ({
      offload.enable = true;
      # 提供 nvidia-offload 命令（__NV_OFFLOAD 环境跑指定程序）
      offload.enableOffloadCmd = true;
      nvidiaBusId = ids.nvidia;
    } // iBus);
  };

  boot.blacklistedKernelModules = [ "nouveau" ];
}
