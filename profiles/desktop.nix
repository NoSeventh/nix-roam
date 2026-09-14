# Desktop host profile: session stack (display manager, audio, graphics,
# printing) plus the explicit desktop module list under modules/desktop/.
# Host-specific settings (boot, kernel, hostname, power buttons, user groups)
# belong in hosts/<hostname>/default.nix, not here.
{ pkgs, pkgs-stable, ... }:

{
  imports = [
    ./nixos-base.nix
    ../modules/desktop/agents.nix
    ../modules/desktop/automation.nix
    ../modules/desktop/flatpak-linyaps.nix
    ../modules/desktop/locale-zh.nix
    ../modules/desktop/mnt.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/programs.nix
    ../modules/desktop/services.nix
    ../modules/desktop/virtualization.nix
  ];

  # --- 1. 显示与会话 ---
  services.xserver.enable = true;
  services.displayManager = {
    defaultSession = "niri";
    gdm.enable = true;
  };

  # services.xserver.displayManager.lightdm = {
  #   enable = true;
  #   greeters.mini.enable = true;
  # };

  # 为 GNOME 视频软件使用 OpenGL 兼容层
  environment.sessionVariables.GDK_GL = "gles";

  # --- 2. 硬件与多媒体 ---
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

  # --- 3. 桌面相关系统软件包 ---
  environment.systemPackages = with pkgs-stable; [
    gnome-extension-manager
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
  ];

  # --- 4. 桌面环境下的 SSH askpass ---
  programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs-stable.seahorse.out}/libexec/seahorse/ssh-askpass";
  #programs.ssh.askPassword = mkDefault "${pkgs.plasma6Packages.ksshaskpass.out}/bin/ksshaskpass";
}
