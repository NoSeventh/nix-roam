# modules/agents/home.nix — agents 层的 standalone 用户级实现
#
# 仅 AI CLI/IDE/客户端。hermes-agent 是系统服务（/etc/hermes 密钥、systemd 单元、
# hermes 组），只留在 NixOS 系统级；opencode 已在 cli-dev 基座，不重复。
{ pkgs, ... }:
with pkgs;
[
  # AI 编辑器/IDE
  code-cursor
  cursor-cli

  # AI Agent 工具
  cc-switch
  agent-browser
  claude-code
  codex
  github-copilot-cli
  opencode-desktop

  # AI 聊天客户端
  cherry-studio
  sillytavern
]
