{ pkgs, lib, ... }:

{
  # ============================================
  # AGENTS.NIX - AI/Agent 相关配置
  # ============================================

  # --- 1. Hermes Agent（最小配置）---
  # DeepSeek 端点与规范模型名由上游内置 provider 插件提供（v0.21+），
  # 密钥经 /etc/hermes/env 的 DEEPSEEK_API_KEY 注入，provider 自动探测。
  # toolsets/plugins/mcpServers 均不声明：toolsets 顶级键上游已废弃，
  # plugins.enabled 是白名单（勿填不存在的插件名），需要时按上游文档再加。
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    settings.model.default = "deepseek/deepseek-flash";
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
    claude-code
    codex
    github-copilot-cli
    # antigravity
    # crush
    # opencode 已移至 packages/cli-dev.nix （共享） 
    opencode-desktop

    # --- 4.3 AI 聊天客户端 ---
    cherry-studio
    # chatbox  # removed from nixpkgs (bundled EOL electron)
    sillytavern
    # lmstudio

  ];
}
