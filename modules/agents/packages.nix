# Shared agents applications for NixOS and standalone Linux.
{ pkgs, ... }:
with pkgs;
[
  # AI Agent 工具
  cc-switch
  agent-browser
  codex
  opencode-desktop

  # AI 聊天客户端
  cherry-studio
  sillytavern
]
