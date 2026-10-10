# Host-specific entry for the current NixOS workstation.
# Machine-specific settings live here (boot, kernel, hostname, power buttons,
# user groups, sshd); shared desktop/session settings live in profiles/desktop.nix.
# To add a new machine: create hosts/<hostname>/ with a default.nix like this
# one (importing the relevant profiles + ./hardware-configuration.nix), then
# add a nixosConfigurations.<hostname> output in flake.nix.
let
  # 可选层默认集（入库）：当前主机的既定组合 = 全部可选层。机器本地 local.nixos.json
  # （gitignored，roam module 维护）经 path: 求值视图整体替换本列表（见 lib/selection.nix）。
  selectionLib = import ../../lib/selection.nix;
in
{ pkgs, pkgs-stable, username, ... }:

{
  imports = [
    ../../profiles/desktop.nix
    (selectionLib.selectionModule {
      front = "nixos";
      key = "nixos";
      default = [
        "flatpak"
        "desktop-managers"
        "browsers"
        "dev"
        "media"
        "office"
        "proxy"
        "gaming"
        "agents"
        "mnt"
        "virtualization"
      ];
    })
    ./hardware-configuration.nix
  ];

  # --- 1. 引导与系统内核 ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];
  # boot.kernelPackages = pkgs.linuxPackages_cachyos; # 使用 cachyos 内核包

  # --- 2. 网络配置 ---
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # --- 3. 电源与登录 ---
  services.logind = {
    settings.Login = {
      HandleLidSwitch = "hibernate"; # 合盖休眠
      HandleLidSwitchExternalPower = "suspend"; # 外接电源时合盖挂起
      HandleLidSwitchDocked = "suspend"; # docked状态（如拓展坞）时合盖挂起
    };
  };

  # --- 4. 用户与安全 ---
  users.users.${username} = {
    extraGroups = [
      "networkmanager"
      "libvirtd"
      "qemu"
      "kvm"
      "docker"
    ];
  };

  services.openssh.enable = true;
}
