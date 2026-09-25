# modules/desktop/flatpak.nix
#
# Flatpak/Linyaps 应用商店与国内镜像（2026-09-26 自 flatpak-linyaps.nix 拆出；
# GNOME/Plasma 备用桌面环境移至 desktop-managers.nix）。
{ pkgs-stable, ... }:

{
  # 1. 开启 Flatpak 和 Linyaps 核心服务
  services.flatpak.enable = true;
  services.linyaps.enable = true;

  # 2. 国内 Flatpak 镜像源配置
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

  # 3. 辅助配置：确保字体在 Flatpak 应用中正常显示
  fonts.fontconfig.enable = true;
}
