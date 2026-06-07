{ config, pkgs, pkgs-stable, lib, ... }:

{
  # ============================================
  # AGENTS.NIX - AI/Agent 相关配置
  # ============================================

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

  # --- 4. AI 相关工具/IDE ---
  environment.systemPackages = with pkgs; [
    # --- 4.1 AI 编辑器/IDE ---
    code-cursor
    cursor-cli

    # --- 4.2 AI Agent 工具 ---
    cc-switch
    agent-browser
    rtk
    claude-code
    codex
    github-copilot-cli
    # antigravity
    # crush
    opencode
    opencode-desktop

    # --- 4.3 AI 聊天客户端 ---
    cherry-studio
    chatbox
    sillytavern
    # lmstudio

  ];
}
