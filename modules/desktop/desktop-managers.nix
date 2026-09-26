# modules/desktop/desktop-managers.nix
#
# 备用桌面环境：GNOME 与 Plasma6（含 GNOME 扩展、KDE 应用与 mutter 实验特性）。
# 主会话 niri 见 niri.nix；2026-09-26 自 flatpak-linyaps.nix 拆出。
{ pkgs-stable, ... }:

{
  # 桌面环境：niri 主会话（GDM defaultSession），gnome/plasma6 日常保留；
  # cosmic 偶尔试验，需要时取消注释
  services.desktopManager.gnome.enable = true;
  services.desktopManager.plasma6.enable = true;
  # services.desktopManager.cosmic = {
  #   enable = true;
  #   xwayland.enable = true;
  # };
  # services.xserver.desktopManager.xfce.enable = true;
  # services.xserver.desktopManager.mate.enable = true;
  # services.xserver.desktopManager.lxqt.enable = true;
  # services.xserver.windowManager.i3.enable = true;
  # services.xserver.windowManager.openbox.enable = true;

  environment.systemPackages = with pkgs-stable; [
    # GNOME 软件
    gnome-software
    gnome-tweaks
    gnome-extension-manager # 自 session.nix 移入：管理下面的 GNOME 扩展，随备用桌面走

    # GNOME 扩展
    gnomeExtensions.blur-my-shell
    gnomeExtensions.just-perfection
    gnomeExtensions.arc-menu
    gnomeExtensions.vitals # 监控设备信息
    gnomeExtensions.kimpanel # 使fcitx5能在gnome中正常使用
    gnomeExtensions.applications-menu
    gnomeExtensions.coverflow-alt-tab
    gnomeExtensions.dash-to-dock
    gnomeExtensions.dash-to-panel

    gnomeExtensions.paperwm
    gnomeExtensions.auto-move-windows
    gnomeExtensions.smart-auto-move
    gnomeExtensions.lunar-calendar
    gnomeExtensions.user-themes

    # KDE 应用
    kdePackages.kdeconnect-kde
    kdePackages.kolourpaint
    kdePackages.calligra
    kdePackages.kdenlive
  ];

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/mutter" = {
          experimental-features = [
            "scale-monitor-framebuffer" # Enables fractional scaling (125% 150% 175%)
            "variable-refresh-rate" # Enables Variable Refresh Rate (VRR) on compatible displays
            "xwayland-native-scaling" # Scales Xwayland applications to look crisp on HiDPI screens
            "autoclose-xwayland" # automatically terminates Xwayland if all relevant X11 clients are gone
          ];
        };
      };
    }
  ];
}
