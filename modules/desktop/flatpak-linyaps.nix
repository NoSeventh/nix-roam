{ pkgs, pkgs-stable, ... }:

{
  # 1. 开启 Flatpak 和 Linyaps核心服务
  services.flatpak.enable = true;
  services.linyaps.enable = true;

  # 2. GNOME && KDE Software 配置（备用）
  services.desktopManager.gnome.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.desktopManager.cosmic = {
    enable = true;
    xwayland.enable = true;
  };
  # services.xserver.desktopManager.xfce.enable = true;
  # services.xserver.desktopManager.mate.enable = true;
  # services.xserver.desktopManager.lxqt.enable = true;
  # services.xserver.windowManager.i3.enable = true;
  # services.xserver.windowManager.openbox.enable = true;
  environment.systemPackages = with pkgs-stable; [
    # GNOME 软件
    gnome-software
    gnome-tweaks

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

  # 3. 国内 Flatpak 镜像源配置
  systemd.services.configure-flatpak-repo = {
    description = "Configure Flatpak Domestic Mirrors";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs-stable.flatpak ];
    script = ''
      # === 选项 A: 上海交通大学 (SJTU) - 推荐 ===
      flatpak remote-add --if-not-exists flathub https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo
      flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub/

      # === 选项 B: 中国科学技术大学 (USTC) - 备用 ===
      # flatpak remote-add --if-not-exists flathub https://mirrors.ustc.edu.cn/flathub/flathub.flatpakrepo
      # flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub/

      # 强制刷新元数据，确保 GNOME Software 搜索结果及时更新
      flatpak update --appstream
    '';
  };

  # 4. 辅助配置：确保字体在 Flatpak 应用中正常显示
  fonts.fontconfig.enable = true;
}
