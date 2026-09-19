# 主机级旋钮：flake.nix 在 nixosConfigurations.wsl 的 specialArgs 加载本文件为 `vars`。
# WSL 图形设备由 Windows 宿主持有，无 GPU profile / gpuBusIDs 需求，当前只有时区。
{
  timeZone = "Asia/Shanghai";
}
