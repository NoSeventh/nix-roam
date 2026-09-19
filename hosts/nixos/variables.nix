# 主机级旋钮：flake.nix 在 nixosConfigurations.nixos 的 specialArgs 加载本文件为 `vars`，
# 需要按主机变化的模块经由函数参数取用（见 profiles/nixos-base.nix 的 timeZone、
# profiles/hardware/nvidia.nix 的 gpuBusIDs）。这里只放机器级参数；
# 身份与远程账号仍在 home/common.nix，hostname/boot 等仍在同目录 default.nix。
{
  timeZone = "Asia/Shanghai";

  # 可选：混合显卡 BusID（十六进制，供 profiles/hardware/nvidia.nix 的 prime offload 用）。
  # 用 `lspci | grep -E 'VGA|3D'` 查出后换算成 PCI:x:y:z 格式再取消注释。示例：
  # gpuBusIDs = {
  #   nvidia = "PCI:1:0:0";
  #   intel = "PCI:0:2:0";
  # };
}
