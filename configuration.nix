{ config, pkgs, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
  ];

  # --- 1. 引导与系统内核 ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

  # --- 2. 网络配置 ---
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # --- 3. Nix 特性设置 (仅保留必要项) ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # --- 4. 区域与桌面 ---
  time.timeZone = "Asia/Shanghai";

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  
  # 为 GNOME 视频软件使用 OpenGL 兼容层
  environment.sessionVariables.GDK_GL = "gles";

  # 启用 Hyprland
  programs.hyprland.enable = true;

  # --- 5. 硬件与多媒体 ---
  services.printing.enable = true;
  # 开启图形加速支持
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
    ];
  };
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  services.logind = {
    lidSwitch = "hibernate"; # 合盖挂起（本机swap分区不够大，无法休眠（hibernate））
    lidSwitchExternalPower = "suspend"; # 外接电源时合盖挂起
    lidSwitchDocked = "suspend"; # docked状态（如拓展坞）时忽略合盖
  };

  # --- 6. 用户与安全 ---
  users.users.xuqihao = {
    isNormalUser = true;
    description = "xuqihao";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "qemu" "kvm" "docker" ]; 
  };

  nixpkgs.config.allowUnfree = true;
  services.openssh.enable = true;
  programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs.seahorse.out}/libexec/seahorse/ssh-askpass";
  #programs.ssh.askPassword = mkDefault "${pkgs.plasma6Packages.ksshaskpass.out}/bin/ksshaskpass";

  # --- 7. 系统软件包 ---
  environment.systemPackages = with pkgs; [
    gnome-extension-manager
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
  ];

  system.stateVersion = "25.05";
}
