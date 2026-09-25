# modules/desktop/proxy.nix
#
# 代理档：clash 系客户端与内核、sing-box 及配套工具（tun/service 模式随 programs.clash-verge）。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
    autoStart = false;
  };

  environment.systemPackages = with pkgs; [
    pkgs-stable.mihomo
    pkgs-stable.clash-verge-rev
    pkgs-stable.clash-nyanpasu
    pkgs-stable.sing-box
    pkgs-stable.v2rayn
    pkgs-stable.proxypin
  ];
}
