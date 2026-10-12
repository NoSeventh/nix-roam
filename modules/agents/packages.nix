# Shared agents applications for NixOS and standalone Linux.
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
