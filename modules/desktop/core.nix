# modules/desktop/core.nix
#
# 桌面基座档：任何桌面主机都需要的开源基础（2026-09-26 自 programs.nix/services.nix 分级拆出）。
# 约束：本档只收开源软件 —— 闭源/专有软件放 browsers.nix / office.nix 等选装档，
# 使轻量主机仅 import 本档即可获得无专有依赖的可用桌面。
# 编辑器与重型开发件在 dev.nix；媒体创作在 media.nix；办公与中文软件在 office.nix；
# 会话栈（niri/终端/输入法）在 niri.nix 与 locale-zh.nix。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
  # --- 1. 系统基础设施 ---
  programs.nix-ld.enable = true;

  # OOM 保险（原 modules/desktop/services.nix）
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  # rustdesk-server 暂不启用：relayHosts 尚未配置真实中继地址，
  # 旧配置的 "example.com" 是占位符，却带着 openFirewall = true 实际开端口。
  # 需要时填入真实 relay host 并取消注释。
  # services.rustdesk-server = {
  #   enable = true;
  #   openFirewall = true;
  #   signal.relayHosts = [ "your-relay.example.org" ];
  # };

  # --- 2. 开源浏览器（programs.* 包装；chrome/edge/servo 见 browsers.nix）---
  programs.firefox.enable = true;
  programs.chromium.enable = true;

  # --- 3. 系统软件包 ---
  environment.systemPackages = with pkgs; [
    # 浏览器（开源基座）
    pkgs-stable.firefox
    pkgs-stable.chromium

    # 终端仿真器
    pkgs-stable.kitty

    # Shell 与终端工具（稳定）
    pkgs-stable.fish
    pkgs-stable.oh-my-fish
    pkgs-stable.starship
    pkgs-stable.chafa

    # 基础工具
    pkgs-stable.git
    # → wget / sshfs / ffmpeg / pandoc / lazygit / sd 等已移至 packages/cli-dev.nix（共享）
    pkgs-stable.lsd

    # 系统监控
    zenith
    impala
    bluetui
    bandwhich
    wego
    # → bottom / btop / procs 已移至 packages/cli-dev.nix（共享）
    pkgs-stable.iftop
    pkgs-stable.iotop
    pkgs-stable.tcping-rs
    pkgs-stable.traceroute
    pkgs-stable.cpu-x

    # 系统信息
    ipfetch
    fastfetch

    # 网络与同步（开源）
    pkgs-stable.wireguard-tools
    pkgs-stable.syncthing
    pkgs-stable.localsend
    # → aria2 / yt-dlp 已移至 packages/cli-dev.nix（共享）
    sftpman

    # 压缩与文档
    pkgs-stable.p7zip
    pkgs-stable.unzip
    pkgs-stable.poppler-utils

    # 截图（录屏 obs 见 media.nix）
    grim
    satty
    flameshot

    # 剪贴板 / 下载 / 认证
    pkgs-stable.copyq
    pkgs-stable.uget
    howdy
  ]
  # 共享 CLI 开发工具（与 home/standalone-linux.nix 同源；系统级安装使 sudo 可见）
  # 平台专用包在 cli-dev.nix 内用 stdenv.hostPlatform.isLinux 条件处理。
  ++ (import ../../packages/cli-dev.nix { inherit pkgs pkgs-stable; });
}
