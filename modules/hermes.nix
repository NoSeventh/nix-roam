{ lib, ... }:

{
  # --- 1. Hermes Agent ---
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings = {
      model = {
        base_url = "https://api.deepseek.com";
        default = "deepseek-v4-flash";
      };
      toolsets = [ "all" ];
      compression = {
        enabled = true;
        threshold = 0.85;
      };
      plugins = {
        enabled = [ "rtk-hermes" ];
      };
    };

    # 声明式 MCP servers
    mcpServers = {
      codegraph = {
        command = "codegraph";
        args = [ "serve" "--mcp" ];
        timeout = 120;
        connect_timeout = 60;
      };
    };

    environmentFiles = [ "/etc/hermes/env" ];
  };

  # --- 2. Hermes 环境变量文件目录 ---
  systemd.tmpfiles.rules = [
    "d /etc/hermes 0750 root hermes - -"
  ];

  # --- 3. 允许当前用户访问 Hermes 共享状态 ---
  users.users.xuqihao.extraGroups = lib.mkAfter [ "hermes" ];
}
