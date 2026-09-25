# Desktop host profile: session stack (display manager, audio, graphics,
# printing) plus the explicit desktop module list under modules/desktop/.
# App tiers: core (open-source base, always) plus optional tiers — browsers /
# dev / media / office / proxy / gaming and the service modules (agents / mnt /
# virtualization). A lighter desktop host composes nixos-base.nix + a subset
# of the tier modules in its own profile instead of importing this full list.
# Host-specific settings (boot, kernel, hostname, power buttons, user groups)
# belong in hosts/<hostname>/default.nix, not here.
{ pkgs, pkgs-stable, ... }:

{
  imports = [
    ./nixos-base.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/locale-zh.nix
    ../modules/desktop/core.nix
    ../modules/desktop/flatpak.nix
    ../modules/desktop/desktop-managers.nix
    ../modules/desktop/browsers.nix
    ../modules/desktop/dev.nix
    ../modules/desktop/media.nix
    ../modules/desktop/office.nix
    ../modules/desktop/proxy.nix
    ../modules/desktop/gaming.nix
    ../modules/desktop/agents.nix
    ../modules/desktop/mnt.nix
    ../modules/desktop/virtualization.nix
    ../modules/desktop/automation.nix
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
  # 开启图形加速支持（32 位支持归 gaming.nix / virtualization.nix 的需求方）
  hardware.graphics.enable = true;

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
