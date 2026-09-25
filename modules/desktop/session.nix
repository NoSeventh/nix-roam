# modules/desktop/session.nix
#
# 桌面会话栈：显示管理（GDM，默认会话 niri）、音频（PipeWire）、打印、图形加速与
# SSH askpass —— 任何桌面主机（全量或 lite）都需要。2026-09-26 自 profiles/desktop.nix
# 抽出为共享模块，供 profiles/desktop.nix 与 profiles/desktop-lite.nix 共同 import。
# compositor/终端在 niri.nix；32 位图形支持在 gaming.nix / virtualization.nix 的需求方。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
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
