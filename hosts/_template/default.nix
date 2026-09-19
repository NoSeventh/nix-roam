# 新主机模板：bootstrap/nixos.sh 检测到 hosts/<target>/ 不存在时会复制本目录并替换
# __HOSTNAME__ 占位符；手工添加机器也照此填写（流程见 AGENTS.md "Adding a new machine"）。
# 约定：目录名 = networking.hostName = flake 输出属性名 nixosConfigurations.<target>
# （nrs / nh os switch 的 --hostname 按主机名自动对上输出，不要起不一致的名字）。
{ username, ... }:

{
  imports = [
    # 默认桌面机：会话栈 + modules/desktop/ 全套（内部已 import profiles/nixos-base.nix）。
    # CLI 服务器改用下面两行（注释掉 desktop 行）：
    # ../../profiles/nixos-base.nix
    # ../../profiles/cli.nix
    ../../profiles/desktop.nix

    # GPU 差异按需三选一（休眠层；默认 mesa 栈对多数场景已够，可不选）：
    # ../../profiles/hardware/nvidia.nix   # NVIDIA / 混合显卡（BusID 配 variables.nix 的 gpuBusIDs）
    # ../../profiles/hardware/amd.nix      # AMD early KMS
    # ../../profiles/hardware/intel.nix    # Intel early KMS + VA-API
    # ../../profiles/hardware/vm-guest.nix # QEMU/KVM 虚拟机客户机

    ./hardware-configuration.nix
  ];

  networking.hostName = "__HOSTNAME__"; # 占位符，脚手架/手工复制后替换为本机 target 名

  # --- 1. 引导（systemd-boot 常规布局；普通 BIOS 或 zfs 机器自行调整） ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- 2. 本机特有设置按需添加（参考 hosts/nixos/default.nix） ---
  # boot.supportedFilesystems = [ "ntfs" ];
  # services.openssh.enable = true;
  # users.users.${username}.extraGroups = [ "networkmanager" "libvirtd" ];
  # 电源/合盖策略、内核参数等同理
}
