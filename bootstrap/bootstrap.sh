#!/usr/bin/env bash
# bootstrap/bootstrap.sh
#
# 统一入口：自动检测当前环境，派发到对应的安装链路（子脚本仍可单独运行，旧入口不失效）。
#
#   macOS             → bootstrap/darwin.sh（aarch64-darwin；Intel Mac 由其守卫拒绝）
#   NixOS / NixOS-WSL → bootstrap/nixos.sh（install/adopt 与 nixos/wsl 由其自检；需要 root，非 root 自动 sudo 拾起）
#   普通 Linux / WSL   → bootstrap/linux.sh（架构自动选 target：x86_64 → <user>，aarch64 → <user>-aarch64；
#                        systemd + sudo → 多用户 Determinate 安装，否则单用户 --no-daemon）
#
# 用法（两种等价入口；参数原样传给子脚本 —— standalone 传 flake target，NixOS 传 install|adopt / --target）：
#     bash bootstrap/bootstrap.sh [参数]     # 仓库内运行
#     bash <(curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/bootstrap.sh)
#                                            # 仓库外一键运行：先把仓库取到 ~/nix-roam 再重跑本脚本
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 仓库定位 / 自取（与 linux.sh / darwin.sh 同款逻辑）---
#     bootstrap/ 相对布局成立且能找到 flake.nix → 仓库内运行，直接用；
#     否则（curl 管道 / 单独下载）先把仓库取到 CLONE_DIR（默认 ~/nix-roam）再 exec 仓库内副本重跑。
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-}")/.." 2>/dev/null && pwd)" || REPO_ROOT=""
if [ -z "$REPO_ROOT" ] || [ ! -f "$REPO_ROOT/flake.nix" ]; then
  CLONE_DIR="${CLONE_DIR:-$HOME/nix-roam}"
  if [ -d "$CLONE_DIR/.git" ] && git -C "$CLONE_DIR" config --get remote.origin.url 2>/dev/null | grep -qE 'nixos-niri-noctalia|nix-roam'; then
    log "复用已有仓库克隆：${CLONE_DIR}（如需更新请自行 git pull --ff-only）"
  else
    if [ -e "$CLONE_DIR" ]; then
      echo "错误：${CLONE_DIR} 已存在且不是本仓库克隆；请移走，或用 CLONE_DIR=<目录> 指定其他位置。" >&2
      exit 1
    fi
    if have git; then
      git clone https://gitee.com/qihaoxu/nixos-niri-noctalia.git "$CLONE_DIR"
    elif have curl; then
      log "无 git，改用 Gitee 压缩包获取仓库"
      mkdir -p "$CLONE_DIR"
      curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/repository/archive/master.tar.gz \
        | tar -xz -C "$CLONE_DIR" --strip-components=1
    else
      echo "错误：仓库外运行需要 git 或 curl，请先安装其一后重试。" >&2
      exit 1
    fi
  fi
  exec bash "$CLONE_DIR/bootstrap/bootstrap.sh" "$@"
fi
cd "$REPO_ROOT"

# --- 环境检测与派发 ---
case "$(uname -s)" in
  Darwin)
    log "检测到 macOS → bootstrap/darwin.sh（Apple Silicon）"
    exec bash "$REPO_ROOT/bootstrap/darwin.sh" "$@"
    ;;

  Linux)
    # NixOS / NixOS-WSL：/etc/NIXOS 标记；install/adopt 模式与 nixos/wsl target 由 nixos.sh 自检
    if [ -e /etc/NIXOS ]; then
      log "检测到 NixOS / NixOS-WSL → bootstrap/nixos.sh（需要 root）"
      if [ "$(id -u)" -eq 0 ]; then
        exec bash "$REPO_ROOT/bootstrap/nixos.sh" "$@"
      else
        exec sudo bash "$REPO_ROOT/bootstrap/nixos.sh" "$@"
      fi
    fi

    # WSL1 守卫（与 linux.sh 同款；WSL2 内核名带 microsoft-standard）
    case "$(uname -r)" in
      *microsoft-standard*|*Microsoft-standard*) ;;
      *[Mm]icrosoft*)
        echo "错误：检测到 WSL1（内核 $(uname -r)）。请先在 Windows 侧执行 wsl --set-version <发行版> 2 升级到 WSL2 后重试。" >&2
        exit 1
        ;;
    esac

    # 架构 → 默认 target（用户名读 flake.nix 单点定义；显式传参优先）
    FLAKE_USER="$(sed -n 's/^ *username = "\([^"]*\)";/\1/p' "$REPO_ROOT/flake.nix" | head -n 1)"
    FLAKE_USER="${FLAKE_USER:-xuqihao}"
    case "$(uname -m)" in
      x86_64)        DEFAULT_TARGET="$FLAKE_USER" ;;
      aarch64|arm64) DEFAULT_TARGET="$FLAKE_USER-aarch64" ;;
      *)
        echo "错误：架构 $(uname -m) 没有对应的 flake 输出（standalone Linux 仅提供 x86_64-linux / aarch64-linux）。" >&2
        exit 1
        ;;
    esac

    # 非 bash 登录 shell：信息性提示（zsh/fish 的会话环境由激活脚本自动兜底，见 standalone-linux.nix）
    case "${SHELL:-}" in
      *zsh|*fish) log "提示：登录 shell 是 ${SHELL##*/}；激活时会自动追加 HM 会话环境加载段" ;;
    esac

    log "检测到普通 Linux/WSL（$(uname -m)）→ bootstrap/linux.sh，target 默认 ${DEFAULT_TARGET}"
    exec bash "$REPO_ROOT/bootstrap/linux.sh" "${1:-$DEFAULT_TARGET}"
    ;;

  *)
    echo "错误：不支持的操作系统 $(uname -s)（本入口支持 Linux / WSL / NixOS / macOS）。" >&2
    exit 1
    ;;
esac
