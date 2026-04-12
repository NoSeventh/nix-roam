{
  config,
  pkgs,
  pkgs-stable,
  inputs,
  ...
}:

{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal.relayHosts = [ "example.com" ];
  };

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  services.mysql = {
    enable = true;
    package = pkgs-stable.mariadb;
  };

}
