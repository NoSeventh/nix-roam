#!/usr/bin/env bash
# bootstrap/linux.sh
#
# 在一台干净的普通 Linux / WSL 上，从零搭建 Nix + Home Manager 便携 CLI 环境。
# 覆盖完整链路：安装 Nix → 配置镜像 → 配置 GitHub token → 开启 flakes → 备份冲突文件 → 安装 HM → 激活。
#
# 统一入口是 bootstrap/bootstrap.sh（自动检测环境后派发到本脚本）；本脚本仍可单独运行。
#
# 用法（两种等价入口，flake target 默认按架构选择：x86_64 → xuqihao，aarch64 → xuqihao-aarch64）：
#     bash bootstrap/linux.sh [flake-target]     # 仓库内运行
#     bash <(curl -fsSL https://gitee.com/qihaoxu/nixos-niri-noctalia/raw/master/bootstrap/linux.sh)
#                                                # 仓库外一键运行：先把仓库取到 ~/nix-roam 再重跑本脚本
#
# 安装模式（环境变量 NIX_INSTALL_MODE，默认 auto）：
#     multi  — systemd + sudo 可用（默认路径）：Determinate 安装器多用户安装，镜像信任写 /etc/nix
#     single — 无 systemd / 无 sudo / 显式指定：官方安装器 --no-daemon 单用户安装，
#              镜像写用户级 nix.conf（无 daemon 无需信任授权；/nix 前缀仍需一次性 root 创建，见步骤 1）
#
# 幂等：可安全重复运行。已完成的步骤会跳过；已被 home-manager 托管的文件（symlink）不会重复备份。
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 0. 平台守卫 ---
[ "$(uname -s)" = "Linux" ] || { echo "错误：此脚本仅用于普通 Linux / WSL；NixOS 请用 bootstrap/nixos.sh，macOS 请用 bootstrap/darwin.sh（或统一入口 bootstrap/bootstrap.sh）。" >&2; exit 1; }

# --- 0.1 WSL1 守卫 ---
#     WSL1 无 systemd 且 syscall 覆盖不全，Nix 要求 WSL2；WSL2 内核名带 microsoft-standard 标记。
case "$(uname -r)" in
  *microsoft-standard*|*Microsoft-standard*) ;;  # WSL2，放行
  *[Mm]icrosoft*)
    echo "错误：检测到 WSL1（内核 $(uname -r)）。请先在 Windows 侧执行 wsl --set-version <发行版> 2 升级到 WSL2 后重试。" >&2
    exit 1
    ;;
esac

# --- 0.5 仓库定位 / 自取 ---
#     bootstrap/ 相对布局成立且能找到 flake.nix → 仓库内运行，直接用；
#     否则（curl 管道 / 单独下载）先把仓库取到 CLONE_DIR（默认 ~/nix-roam）再 exec 仓库内副本重跑。
#     git 优先；无 git 时退到 Gitee 压缩包（非 git 克隆，日后更新请改用 git clone）。
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
  exec bash "$CLONE_DIR/bootstrap/linux.sh" "$@"
fi
cd "$REPO_ROOT"

# --- 0.6 默认 target 按架构 ---
#     用户名读取 flake.nix 顶部单点定义（与 nixos.sh 同法）；默认 target：
#     x86_64 → <username>，aarch64 → <username>-aarch64；显式传参可覆盖。
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
FLAKE_TARGET="${1:-$DEFAULT_TARGET}"

TS="$(date +%Y%m%d-%H%M%S)"
NIX_CONF="$HOME/.config/nix/nix.conf"
GITHUB_TOKEN_CONF="$HOME/.config/nix/github-access-tokens.conf"

# --- 0.7 目标用户守卫 ---
#     standalone HM 只能为当前用户激活：target 用户名与当前登录用户不符时直接中止，
#     避免出现「先改了系统 nix 配置、激活阶段才写不进他人 HOME」的半配置状态。
#     换用户名使用本仓库：改 flake.nix 顶部 username 单点定义，再传对应 target。
TARGET_USER="$(printf '%s' "$FLAKE_TARGET" | sed -E 's/-(aarch64|darwin)$//')"
if [ "$(id -un)" != "$TARGET_USER" ]; then
  echo "错误：当前用户 $(id -un) 与 flake target ${FLAKE_TARGET} 的用户 ${TARGET_USER} 不一致。" >&2
  echo "      如需以 $(id -un) 使用本仓库：编辑 flake.nix 顶部 username = \"$(id -un)\"（单点定义），" >&2
  echo "      然后运行 bash bootstrap/linux.sh $(id -un)。" >&2
  exit 1
fi

# --- 0.8 安装模式判定 ---
#     multi = systemd + sudo（Determinate 多用户 + /etc/nix daemon 信任，与旧版行为一致）；
#     single = 其余情况（官方安装器 --no-daemon：无 systemd / 无 sudo 均可走，镜像走用户级配置）。
#     NIX_INSTALL_MODE=multi|single 可显式指定；auto 按环境自动选择。
if [ "${NIX_INSTALL_MODE:-auto}" = "auto" ]; then
  if [ -d /run/systemd/system ] && have sudo && sudo -v 2>/dev/null; then
    NIX_INSTALL_MODE=multi
  else
    NIX_INSTALL_MODE=single
  fi
fi
case "$NIX_INSTALL_MODE" in
  multi|single) ;;
  *) echo "错误：NIX_INSTALL_MODE 仅支持 multi / single / auto（当前：${NIX_INSTALL_MODE}）。" >&2; exit 1 ;;
esac
if [ "$NIX_INSTALL_MODE" = "multi" ] && [ ! -d /run/systemd/system ]; then
  echo "错误：multi 模式需要 systemd（Determinate 安装器依赖）；本机无 systemd，请用 NIX_INSTALL_MODE=single。" >&2
  exit 1
fi
log "安装模式：${NIX_INSTALL_MODE}-user（systemd: $([ -d /run/systemd/system ] && echo yes || echo no)，sudo: $(have sudo && echo yes || echo no)）"

# ---------------------------------------------------------------------------
# 1/7 安装 Nix
#     multi ：Determinate Systems 安装器（默认开启 flakes）
#     single：官方安装器 --no-daemon；/nix 是硬编码前缀，缺失且无 sudo 时给出管理员命令后退出
# ---------------------------------------------------------------------------
log "1/7 安装 Nix（${NIX_INSTALL_MODE}-user）"
if have nix; then
  echo "    nix 已安装，跳过"
else
  if [ "$NIX_INSTALL_MODE" = "single" ]; then
    if [ -d /nix ] && [ ! -w /nix ]; then
      echo "错误：/nix 已存在但当前用户不可写。请让管理员执行 sudo chown $(id -un) /nix 后重试。" >&2
      exit 1
    fi
    if [ ! -d /nix ] && ! have sudo; then
      cat >&2 <<EOF
错误：单用户安装仍需一次 root 操作创建 /nix（Nix store 前缀硬编码为 /nix）。
请让管理员执行：
    sudo mkdir -m 0755 /nix && sudo chown $(id -un) /nix
之后重新运行本脚本（此后全程无需 root）。若本机有 sudo，可去掉 NIX_INSTALL_MODE=single 走多用户安装。
EOF
      exit 1
    fi
    curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon
    # 单用户安装后加载 nix 环境
    # shellcheck disable=SC1090  # 加载已知 nix profile 路径
    [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
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
fi
have nix || { echo "错误：nix 仍不可用。请打开新 shell 让 nix 进 PATH 后重试。" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 2/7 配置国内镜像
#     multi ：写 /etc/nix/nix.custom.conf 的 trusted-substituters 并让 nix.conf include（daemon 侧授权，
#             用户级 substituters 才会被多用户 daemon 接受）
#     single：无 daemon，用户级 nix.conf 的 substituters 直接生效，无需任何授权
#     幂等：两种模式均已配置时跳过；用户 nix.conf 已是 HM 托管 symlink 时不追加（nix-cn.nix 接管同一列表）
# ---------------------------------------------------------------------------
log "2/7 配置国内镜像（${NIX_INSTALL_MODE}-user）"
TRUSTED_SUBSTITUTERS="https://mirror.nju.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://mirror.sjtu.edu.cn/nix-channels/store"
if [ "$NIX_INSTALL_MODE" = "multi" ]; then
  NIX_CUSTOM_CONF="/etc/nix/nix.custom.conf"
  NIX_SYSTEM_CONF="/etc/nix/nix.conf"
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
else
  mkdir -p "$(dirname "$NIX_CONF")"
  if [ -L "$NIX_CONF" ]; then
    echo "    $NIX_CONF 已是 Home Manager 托管 symlink，跳过（nix-cn.nix 管理同一镜像列表）"
  elif [ -f "$NIX_CONF" ] && grep -q '^substituters' "$NIX_CONF"; then
    echo "    用户级 substituters 已配置，跳过"
  else
    echo "substituters = $TRUSTED_SUBSTITUTERS https://cache.nixos.org/" >> "$NIX_CONF"
    echo "    已写入用户级 substituters（$NIX_CONF）"
  fi
  # 本次会话立即生效（后续 nix profile install / home-manager 拉包直接走国内镜像）
  export NIX_CONFIG="substituters = $TRUSTED_SUBSTITUTERS https://cache.nixos.org/"
fi

# ---------------------------------------------------------------------------
# 3/7 配置 GitHub token（可选）
#     token 只写入仓库外的 0600 文件，nix.conf 仅 include 该文件。
#     用户 nix.conf 若已是 HM 托管 symlink 则跳过追加（standalone-*.nix 的 nix.extraOptions 携带该 include）。
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
if [ -L "$NIX_CONF" ]; then
  echo "    $NIX_CONF 已是 Home Manager 托管 symlink，跳过追加 token include"
elif ! grep -Fqx "$TOKEN_INCLUDE" "$NIX_CONF" 2>/dev/null; then
  printf '%s\n' "$TOKEN_INCLUDE" >> "$NIX_CONF"
fi

# ---------------------------------------------------------------------------
# 4/7 永久开启 flakes（写入用户 nix.conf，以后直接敲 nix 命令无需额外 flag）
#     同样尊重 HM 托管 symlink（nix-cn.nix 已含 experimental-features）。
# ---------------------------------------------------------------------------
log "4/7 永久开启 flakes"
mkdir -p "$(dirname "$NIX_CONF")"
if [ -L "$NIX_CONF" ]; then
  echo "    $NIX_CONF 已是 Home Manager 托管 symlink，跳过（nix-cn.nix 已开启 flakes）"
elif [ -f "$NIX_CONF" ] && grep -q '^experimental-features' "$NIX_CONF"; then
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

  · 安装模式：${NIX_INSTALL_MODE}-user$( [ "$NIX_INSTALL_MODE" = "single" ] && echo '（无 daemon：镜像/ flakes/token 均在用户级 nix.conf；升级 nix 本体请重跑官方安装器）' )
  · 被接管文件的原版备份在：~/*.bak-${TS} 与 ~/.profile.backup
  · ⚠️ programs.ssh 用 enableDefaultConfig=false，新 ~/.ssh/config 只含 HM 定义的 host。
    如果你旧 ssh config（备份在 ~/.ssh/config.bak-${TS}）里还有别的 host，需要手动合并回
    home/common.nix 的 programs.ssh。
  · 登录 shell 若不是 bash：激活时已自动向 ~/.zshrc / fish config 追加带守卫的
    HM 会话环境加载段（fish 无 bass 时仅加 PATH，完整变量需 bash/zsh 或安装 bass）。
  · 以后更新配置： cd ${REPO_ROOT} && home-manager switch --flake .#${FLAKE_TARGET}
EOF
