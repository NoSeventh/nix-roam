{ lib, ... }:

{
  # --- 1. Hermes Agent ---
  services.hermes-agent = {
    enable = true;
    settings = {
      model = {
        base_url = "https://api.deepseek.com";
        default = "deepseek-v4-flash";
      };
      toolsets = [ "all" ];
    };
    environmentFiles = [ "/etc/hermes/env" ];
    addToSystemPackages = true;
  };

  # --- 2. Hermes 环境变量文件目录 ---
  systemd.tmpfiles.rules = [
    "d /etc/hermes 0750 root hermes - -"
  ];

  # --- 3. 允许当前用户访问 Hermes 共享状态 ---
  users.users.xuqihao.extraGroups = lib.mkAfter [ "hermes" ];
}
