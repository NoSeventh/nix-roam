# 主机级旋钮：flake.nix 在本主机的 nixosConfigurations.<target> specialArgs 里
# 加载本文件为 `vars`（接线点唯一；说明见 hosts/nixos/variables.nix）。
{
  timeZone = "Asia/Shanghai";

  # 混合显卡（NVIDIA + 核显）且 import 了 profiles/hardware/nvidia.nix 时取消注释：
  # `lspci | grep -E 'VGA|3D'` 查出后换算成 PCI:x:y:z 格式。
  # gpuBusIDs = {
  #   nvidia = "PCI:1:0:0";
  #   intel = "PCI:0:2:0";
  # };
}
