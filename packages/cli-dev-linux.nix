# packages/cli-dev-linux.nix
#
# Linux 专用 CLI / 开发工具列表 —— 纯函数，返回 package list。
# 被两处导入（与 cli-dev.nix 对称）：
#   - modules/programs.nix   → NixOS 的 environment.systemPackages（系统级、sudo 可见）
#   - home/standalone-linux.nix → 非 NixOS Linux 的 home.packages（用户级）
#
# 只放 Linux-only 的纯命令行工具。
{ pkgs, pkgs-stable, ... }:

with pkgs; [
  # --- 开发工具（Linux-only） ---
  pkgs-stable.valgrind

  # --- 科学计算（Linux-only） ---
  pkgs-stable.root

  # --- Python 科学计算（Linux-only） ---
  # 注意：此处的 python3.withPackages 会与 cli-dev.nix 中的交叉平台 Python 环境
  # 共存于同一 profile（NixOS environment.systemPackages 或 HM home.packages），
  # 两者无冲突 —— Nix 的 buildEnv 可合并多个 python3 包装器。
  (python3.withPackages (
    python-pkgs: with python-pkgs; [
      root
      uproot
      rpy2
      torch
    ]
  ))
]
