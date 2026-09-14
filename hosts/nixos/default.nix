# Host-specific entry for the current NixOS workstation.
# Machine-specific settings live here (boot, kernel, hostname, power buttons,
# user groups, sshd); shared desktop/session settings live in profiles/desktop.nix.
# To add a new machine: create hosts/<hostname>/ with a default.nix like this
# one (importing the relevant profiles + ./hardware-configuration.nix), then
# add a nixosConfigurations.<hostname> output in flake.nix.
{ pkgs, pkgs-stable, ... }:

{
  imports = [
    ../../profiles/desktop.nix
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
  users.users.xuqihao = {
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
