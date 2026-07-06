#!/usr/bin/env bash
# bootstrap/linux.sh
#
# 在一台干净的 Linux / WSL 上搭建 Nix + Home Manager 便携 CLI 环境。
# 前置：已 git clone 本仓库，并在仓库根目录运行：  bash bootstrap/linux.sh
# 可选参数：第一个参数为 flake target，默认 xuqihao。
set -euo pipefail

# 切到仓库根（脚本位于 bootstrap/ 下）
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FLAKE_TARGET="${1:-xuqihao}"

echo "==> 1/2 安装 Nix（Determinate Systems 安装器，默认开启 flakes）"
if ! command -v nix >/dev/null 2>&1; then
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install
  # 加载 nix 环境变量
  for f in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    [ -f "$f" ] && . "$f" && break
  done
else
  echo "    nix 已安装，跳过"
fi

echo "==> 2/2 激活 Home Manager（flake target: ${FLAKE_TARGET}）"
nix run "github:nix-community/home-manager" -- switch --flake ".#${FLAKE_TARGET}"

echo "==> 完成。重新打开 shell（或 source ~/.bashrc）以加载新环境。"
