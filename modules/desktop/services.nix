{
  pkgs-stable,
  ...
}:

{
  # rustdesk-server 暂不启用：relayHosts 尚未配置真实中继地址，
  # 旧配置的 "example.com" 是占位符，却带着 openFirewall = true 实际开端口。
  # 需要时填入真实 relay host 并取消注释。
  # services.rustdesk-server = {
  #   enable = true;
  #   openFirewall = true;
  #   signal.relayHosts = [ "your-relay.example.org" ];
  # };

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  services.mysql = {
    enable = true;
    package = pkgs-stable.mariadb;
  };

}
