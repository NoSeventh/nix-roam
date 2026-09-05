#!/usr/bin/env bash
# bootstrap/linux.sh
#
# 在一台干净的普通 Linux / WSL 上，从零搭建 Nix + Home Manager 便携 CLI 环境。
# 覆盖完整链路：安装 Nix → 配置镜像 → 配置 GitHub token → 开启 flakes → 备份冲突文件 → 安装 HM → 激活。
#
# 前置：已 git clone 本仓库。在仓库根目录运行：
#     bash bootstrap/linux.sh [flake-target]     # 默认 target = xuqihao
#
# 幂等：可安全重复运行。已完成的步骤会跳过；已被 home-manager 托管的文件（symlink）不会重复备份。
set -euo pipefail

# 切到仓库根（脚本位于 bootstrap/ 下）
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FLAKE_TARGET="${1:-xuqihao}"
TS="$(date +%Y%m%d-%H%M%S)"
NIX_CONF="$HOME/.config/nix/nix.conf"
GITHUB_TOKEN_CONF="$HOME/.config/nix/github-access-tokens.conf"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# 1/7 安装 Nix（Determinate Systems 安装器，默认开启 flakes）
# ---------------------------------------------------------------------------
log "1/7 安装 Nix"
if have nix; then
  echo "    nix 已安装，跳过"
else
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install
  # 加载 nix 环境变量（多用户优先，单用户兜底）
  for f in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    # shellcheck disable=SC1090  # 动态加载已知 nix profile 路径
    [ -f "$f" ] && . "$f" && break
  done
fi
have nix || { echo "错误：nix 仍不可用。请打开新 shell 让 nix 进 PATH 后重试。" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 2/7 配置国内镜像信任（多用户 daemon 下让用户级 substituters 生效）
#     幂等：维护 nix.custom.conf 的镜像列表，并确保 nix.conf 实际 include 它。
# ---------------------------------------------------------------------------
log "2/7 配置国内镜像信任"
NIX_CUSTOM_CONF="/etc/nix/nix.custom.conf"
NIX_SYSTEM_CONF="/etc/nix/nix.conf"
TRUSTED_SUBSTITUTERS="https://mirror.nju.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://mirror.sjtu.edu.cn/nix-channels/store"
if [ -f "$NIX_CUSTOM_CONF" ] && sudo grep -q "mirror.nju.edu.cn/nix-channels/store" "$NIX_CUSTOM_CONF"; then
  echo "    已配置国内镜像信任，跳过"
else
  sudo mkdir -p /etc/nix
  if [ -f "$NIX_CUSTOM_CONF" ] && sudo grep -q '^trusted-substituters' "$NIX_CUSTOM_CONF"; then
    sudo sed -i "s|^trusted-substituters = .*|trusted-substituters = $TRUSTED_SUBSTITUTERS|" "$NIX_CUSTOM_CONF"
  else
    printf 'trusted-substituters = %s\n' "$TRUSTED_SUBSTITUTERS" | sudo tee -a "$NIX_CUSTOM_CONF" > /dev/null
  fi
  echo "    已写入 $NIX_CUSTOM_CONF"
fi
if [ ! -f "$NIX_SYSTEM_CONF" ] || ! sudo grep -Eq '^!include[[:space:]]+(nix\.custom\.conf|/etc/nix/nix\.custom\.conf)$' "$NIX_SYSTEM_CONF"; then
  printf '\n!include nix.custom.conf\n' | sudo tee -a "$NIX_SYSTEM_CONF" > /dev/null
  echo "    已让 $NIX_SYSTEM_CONF 加载 nix.custom.conf"
fi

# ---------------------------------------------------------------------------
# 3/7 配置 GitHub token（可选）
#     token 只写入仓库外的 0600 文件，nix.conf 仅 include 该文件。
# ---------------------------------------------------------------------------
log "3/7 配置 GitHub token（缓解 API 限流）"
mkdir -p "$(dirname "$NIX_CONF")"
if [ -t 0 ]; then
  read -r -s -p "    粘贴新 GitHub token（回车确认，留空沿用旧值）: " GITHUB_TOKEN
  echo
  if [ -n "$GITHUB_TOKEN" ]; then
    if [[ "$GITHUB_TOKEN" =~ [[:space:]] ]]; then
      echo "错误：GitHub token 不应包含空白字符。" >&2
      exit 1
    fi
    install -m 600 /dev/null "$GITHUB_TOKEN_CONF"
    printf 'access-tokens = github.com=%s\n' "$GITHUB_TOKEN" > "$GITHUB_TOKEN_CONF"
    unset GITHUB_TOKEN
    echo "    已安全写入 $GITHUB_TOKEN_CONF（权限 0600）"
  elif [ -s "$GITHUB_TOKEN_CONF" ]; then
    echo "    未输入新 token，继续沿用旧值"
  else
    echo "    未输入 token，当前保持未配置"
  fi
else
  echo "    当前非交互终端，保留现有 token 配置"
fi

TOKEN_INCLUDE="!include $GITHUB_TOKEN_CONF"
if ! grep -Fqx "$TOKEN_INCLUDE" "$NIX_CONF" 2>/dev/null; then
  printf '%s\n' "$TOKEN_INCLUDE" >> "$NIX_CONF"
fi

# ---------------------------------------------------------------------------
# 4/7 永久开启 flakes（写入用户 nix.conf，以后直接敲 nix 命令无需额外 flag）
# ---------------------------------------------------------------------------
log "4/7 永久开启 flakes"
mkdir -p "$(dirname "$NIX_CONF")"
if [ -f "$NIX_CONF" ] && grep -q '^experimental-features' "$NIX_CONF"; then
  echo "    已开启：$(grep '^experimental-features' "$NIX_CONF")"
else
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
  echo "    已写入 experimental-features = nix-command flakes"
fi

# ---------------------------------------------------------------------------
# 5/7 备份将被 home-manager 接管的家目录文件
#     仅备份「真实文件」；若已是 symlink（说明 HM 已托管），跳过 —— 保证幂等。
# ---------------------------------------------------------------------------
log "5/7 备份将被接管的文件"
for f in "$HOME/.bashrc" "$HOME/.gitconfig" "$HOME/.ssh/config" "$HOME/.profile"; do
  if [ -e "$f" ] && [ ! -L "$f" ]; then
    mkdir -p "$(dirname "$f")"
    cp -a "$f" "$f.bak-$TS"
    rm -f "$f"
    echo "    备份并移除：$f  ->  $f.bak-$TS"
  fi
done

# ---------------------------------------------------------------------------
# 6/7 永久安装 home-manager（nix profile install，命令常驻 ~/.nix-profile/bin）
# ---------------------------------------------------------------------------
log "6/7 安装 home-manager（永久）"
export PATH="$HOME/.nix-profile/bin:$PATH"
if have home-manager; then
  echo "    home-manager 已安装，跳过"
else
  nix profile install github:nix-community/home-manager
fi
have home-manager || { echo "错误：home-manager 安装失败。" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 7/7 激活便携 CLI 环境
#     -b backup：任何残留冲突文件自动加 .backup 后缀（兜底，避免激活中途失败）
# ---------------------------------------------------------------------------
log "7/7 激活 flake target: ${FLAKE_TARGET}"
home-manager switch -b backup --flake ".#${FLAKE_TARGET}"

cat <<EOF

完成。请打开新 shell（或 exec bash -l）以加载新环境。

  · 被接管文件的原版备份在：~/*.bak-${TS} 与 ~/.profile.backup
  · ⚠️ programs.ssh 用 enableDefaultConfig=false，新 ~/.ssh/config 只含 HM 定义的 host。
    如果你旧 ssh config（备份在 ~/.ssh/config.bak-${TS}）里还有别的 host，需要手动合并回
    home/common.nix 的 programs.ssh。
  · 以后更新配置： cd ${REPO_ROOT} && home-manager switch --flake .#${FLAKE_TARGET}
EOF
