#!/usr/bin/env bash
# bootstrap/linux.sh
#
# 在一台干净的普通 Linux / WSL 上，从零搭建 Nix + Home Manager 便携 CLI 环境。
# 覆盖完整链路：安装 Nix → 配置镜像 → 配置 GitHub token → 开启 flakes → 备份冲突文件 → 安装 HM → 激活。
#
# 统一入口是 bootstrap/bootstrap.sh（自动检测环境后派发到本脚本）；本脚本仍可单独运行。
#
# 用法（两种等价入口，flake target 默认按架构选择：x86_64 → x86_64-linux，aarch64 → aarch64-linux）：
#     bash bootstrap/linux.sh [flake-target]     # 仓库内运行
#     bash <(curl -fsSL https://gitee.com/qihaoxu/nix-roam/raw/master/bootstrap/linux.sh)
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

# 合并 WSL 默认用户到 /etc/wsl.conf 的 [user] 段（输出到 stdout，不落盘）：
# 已有 [user] 段 → 在段头下插入/替换 default=<user> 并丢弃旧 default 行（其余段落与键原样保留）；
# 没有 [user] 段 → 文件末尾（空行分隔）追加；输入为空/不存在 → 只输出 [user] 段。
# 纯 bash 实现：精简发行版（含作者自己的 Fedora WSL）可能连 gawk 都没装，不假设 awk 存在。
wsl_conf_merge() {  # $1 = username, $2 = 输入文件（可为 /dev/null）
  local u="$1" in="$2" line inuser=0 wrote=0 nlines=0
  while IFS= read -r line || [ -n "$line" ]; do
    nlines=$((nlines + 1))
    if [[ "$line" =~ ^[[:space:]]*\[[^]]*\][[:space:]]*$ ]]; then
      if [ "${line//[[:space:]]/}" = "[user]" ]; then
        inuser=1; printf '%s\n' "$line"
        if [ "$wrote" -eq 0 ]; then printf 'default=%s\n' "$u"; wrote=1; fi
        continue
      fi
      inuser=0
    fi
    if [ "$inuser" -eq 1 ] && [[ "$line" =~ ^[[:space:]]*default[[:space:]]*= ]]; then
      continue
    fi
    printf '%s\n' "$line"
  done < "$in"
  if [ "$wrote" -eq 0 ]; then
    [ "$nlines" -eq 0 ] || printf '\n'
    printf '[user]\ndefault=%s\n' "$u"
  fi
}

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
      git clone https://gitee.com/qihaoxu/nix-roam.git "$CLONE_DIR"
    elif have curl; then
      log "无 git，改用 Gitee 压缩包获取仓库"
      mkdir -p "$CLONE_DIR"
      curl -fsSL https://gitee.com/qihaoxu/nix-roam/repository/archive/master.tar.gz \
        | tar -xz -C "$CLONE_DIR" --strip-components=1
    else
      echo "错误：仓库外运行需要 git 或 curl，请先安装其一后重试。" >&2
      exit 1
    fi
  fi
  exec bash "$CLONE_DIR/bootstrap/linux.sh" "$@"
fi
cd "$REPO_ROOT"

# --- 运行日志：全程 tee 到带时间戳的文件，事后排查用（token 输入走 stdin 不入日志）---
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nix-roam"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/linux-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
log "运行日志：$LOG_FILE"

# --- 0.6 默认 target 按架构 ---
#     standalone 输出名即系统名（flake.nix 的 homeConfigurations.x86_64-linux / aarch64-linux），
#     不随用户名变化；默认 target 按本机架构选择，显式传参必须与本机架构一致（fail-loud）。
case "$(uname -m)" in
  x86_64)        DEFAULT_TARGET="x86_64-linux" ;;
  aarch64|arm64) DEFAULT_TARGET="aarch64-linux" ;;
  *)
    echo "错误：架构 $(uname -m) 没有对应的 flake 输出（standalone Linux 仅提供 x86_64-linux / aarch64-linux）。" >&2
    exit 1
    ;;
esac
FLAKE_TARGET="${1:-$DEFAULT_TARGET}"
if [ "$FLAKE_TARGET" != "$DEFAULT_TARGET" ]; then
  echo "错误：target ${FLAKE_TARGET} 与本机架构不符（$(uname -m) 对应 ${DEFAULT_TARGET}；" >&2
  echo "      standalone Linux 仅 x86_64-linux / aarch64-linux 两个输出，switch 必须在本机架构上运行）。" >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
NIX_CONF="$HOME/.config/nix/nix.conf"
GITHUB_TOKEN_CONF="$HOME/.config/nix/github-access-tokens.conf"

# --- 0.7 目标用户守卫 ---
#     standalone HM 只能为当前用户激活：meta.json 单点定义的用户名与当前登录用户不符时——
#       · 目标用户已存在：不改动既有账号，提示直接以它登录重跑（root 可 su -l），或改 meta.json；
#       · 交互终端且有提权能力（root 本身，或非 root 可 sudo）：询问是否创建该系统用户并切换
#         过去继续（useradd -m + 交互设密码 + best-effort 提权组，仓库复制到新用户家目录后
#         以它重跑本脚本）——与 NixOS 侧「flake 直接 users.users.<username> 建号」对齐。
#         root 直跑不加 sudo 前缀、切换用 runuser（缺失退 su -l）；无 sudo 二进制的机器上
#         预建 /nix 并 chown 给新用户，让重跑落入单用户安装（多用户安装需要提权）。
#       · 否则：fail-loud 中止并给出改 meta.json 单点定义的指引。
#     均发生在改动任何系统 nix 配置之前，避免半配置状态。
FLAKE_USER="$(sed -n 's/.*"username": *"\([^"]*\)".*/\1/p' "$REPO_ROOT/meta.json" | head -n 1)"
[ -n "$FLAKE_USER" ] || { echo "错误：无法从 meta.json 解析 username（文件缺失或格式变化）。" >&2; exit 1; }
CURRENT_USER="$(id -un)"
if [ "$CURRENT_USER" != "$FLAKE_USER" ]; then
  if id "$FLAKE_USER" >/dev/null 2>&1; then
    echo "错误：当前用户 ${CURRENT_USER} 与 meta.json 定义的 username ${FLAKE_USER} 不一致，且系统已存在用户 ${FLAKE_USER}（不改动既有账号）。" >&2
    echo "      请以 ${FLAKE_USER} 登录后重跑本脚本（root 可直接 su -l ${FLAKE_USER}；WSL 可从 Windows 侧 wsl -u ${FLAKE_USER} 进入），" >&2
    echo "      或编辑 meta.json 的 username 为 \"${CURRENT_USER}\"（单点定义）后重跑。" >&2
    exit 1
  fi
  IS_ROOT=0; [ "$(id -u)" -eq 0 ] && IS_ROOT=1
  PRIV_OK=0
  if [ "$IS_ROOT" -eq 1 ] || { have sudo && sudo -v 2>/dev/null; }; then PRIV_OK=1; fi
  if [ -t 0 ] && [ "$PRIV_OK" -eq 1 ]; then
    read -r -p "当前用户 ${CURRENT_USER} 与 meta.json 定义的 username ${FLAKE_USER} 不一致。创建系统用户 ${FLAKE_USER} 并以它继续安装？[y/N] " GUARD_ANSWER
    case "$GUARD_ANSWER" in
      y|Y)
        # root 直跑不加 sudo 前缀；非 root 借当前会话的 sudo 提权
        if [ "$IS_ROOT" -eq 1 ]; then SUDO=""; else SUDO="sudo"; fi
        echo "    创建用户 ${FLAKE_USER}（useradd -m，shell 用 bash）"
        $SUDO useradd -m -s "$(command -v bash)" "$FLAKE_USER" || { echo "错误：useradd ${FLAKE_USER} 失败。" >&2; exit 1; }
        # 提权组：Debian 系 sudo 组 / RHEL 系 wheel，都尝试（不存在的组跳过）；
        # 连 sudo 二进制都没有的机器上加组无意义，跳过并说明（届时走单用户安装）
        if have sudo; then
          $SUDO usermod -aG sudo  "$FLAKE_USER" 2>/dev/null || true
          $SUDO usermod -aG wheel "$FLAKE_USER" 2>/dev/null || true
          id -nG "$FLAKE_USER" | tr ' ' '\n' | grep -qx -e sudo -e wheel \
            || echo "    ⚠️ 未能把 ${FLAKE_USER} 加入 sudo/wheel 提权组（发行版差异）；多用户安装需要提权，请以该用户登录后自行加入再重跑。"
        else
          echo "    本机未安装 sudo：新用户将走单用户安装（无需提权；日后装 sudo 并加入 wheel/sudo 组可转多用户）"
        fi
        $SUDO passwd "$FLAKE_USER"  # 交互设置登录密码（登录与 sudo 提权都要用）
        # root 且无 sudo：预建 /nix 并属新用户（单用户安装的一次性 root 步骤，重跑时免管理员介入）
        if [ "$IS_ROOT" -eq 1 ] && ! have sudo && [ ! -d /nix ]; then
          mkdir -m 0755 /nix && chown "$FLAKE_USER:" /nix \
            && echo "    已预创建 /nix 并属 ${FLAKE_USER}（单用户安装前提）"
        fi
        # 仓库复制到新用户家目录（归其所有，日后可 git pull）；失败则退回当前副本（只读使用）
        NEW_HOME="$(getent passwd "$FLAKE_USER" 2>/dev/null | cut -d: -f6)"
        [ -n "$NEW_HOME" ] || NEW_HOME="/home/$FLAKE_USER"
        NEW_REPO=""
        if [ "$IS_ROOT" -eq 1 ]; then
          if cp -a "$REPO_ROOT" "$NEW_HOME/nix-roam" 2>/dev/null && chown -R "$FLAKE_USER:" "$NEW_HOME/nix-roam" 2>/dev/null; then
            NEW_REPO="$NEW_HOME/nix-roam"
          fi
        elif sudo -u "$FLAKE_USER" cp -a "$REPO_ROOT" "$NEW_HOME/nix-roam" 2>/dev/null; then
          NEW_REPO="$NEW_HOME/nix-roam"
        fi
        if [ -n "$NEW_REPO" ]; then
          echo "    仓库已复制到 ${NEW_REPO}（属 ${FLAKE_USER}，日常更新在其中进行）"
        else
          echo "    ⚠️ 复制仓库到 ${NEW_HOME} 失败，改用当前副本 ${REPO_ROOT}（只读使用；新用户日后请自行克隆）"
        fi
        # WSL：询问是否把新用户设为默认登录用户（/etc/wsl.conf 的 [user] 段）。
        #     合并而非覆盖：保留已有段落与键，仅增/换 default 一行；原文件带时间戳备份；
        #     写入失败只警告不中断安装（默认用户是便利项，不影响本次以新用户继续）。
        case "$(uname -r)" in
          *microsoft-standard*|*Microsoft-standard*)
            WSL_CONF="/etc/wsl.conf"
            read -r -p "    要把 ${FLAKE_USER} 设为 WSL 默认登录用户吗？（写入 ${WSL_CONF}，Windows 侧 wsl --shutdown 重开后生效）[Y/n] " WSL_ANSWER
            case "$WSL_ANSWER" in
              n|N)
                echo "    跳过。如需手动设置：在 ${WSL_CONF} 的 [user] 段加 default=${FLAKE_USER} 后 wsl --shutdown 重开。"
                ;;
              *)
                WSL_IN="$WSL_CONF"; [ -f "$WSL_CONF" ] || WSL_IN=/dev/null
                WSL_TMP="$(mktemp)"
                if wsl_conf_merge "$FLAKE_USER" "$WSL_IN" > "$WSL_TMP" 2>/dev/null \
                   && { [ ! -f "$WSL_CONF" ] || $SUDO cp -a "$WSL_CONF" "$WSL_CONF.bak-$TS"; } \
                   && $SUDO cp "$WSL_TMP" "$WSL_CONF"; then
                  rm -f "$WSL_TMP"
                  echo "    已写入 ${WSL_CONF}（原文件备份在 ${WSL_CONF}.bak-${TS}）；Windows 侧 wsl --shutdown 重开后默认以 ${FLAKE_USER} 进入。"
                else
                  rm -f "$WSL_TMP"
                  echo "    ⚠️ 写入 ${WSL_CONF} 失败，请手动在 [user] 段加 default=${FLAKE_USER} 后 wsl --shutdown 重开（安装继续）。"
                fi
                ;;
            esac
            ;;
        esac
        RERUN="${NEW_REPO:-$REPO_ROOT}/bootstrap/linux.sh"
        log "以 ${FLAKE_USER} 重跑本脚本（日志将切到该用户名下的新文件）…"
        if [ "$IS_ROOT" -eq 1 ]; then
          # root 切换用户。su 为主：PAM 栈是纯 pam_unix，WSL 里 logind/pam_systemd 异常时
          # 依然可用（实测 ArchLinux-WSL 上 runuser 的 session include system-login 会挂死），
          # 且 root 用 su 免密；多参数形式有 util-linux 怪癖，统一 -c 单串 + %q 消毒。
          RERUN_CMD="$(printf 'bash %q %q' "$RERUN" "$FLAKE_TARGET")"
          if have su; then
            exec su --login "$FLAKE_USER" -c "$RERUN_CMD"
          else
            exec runuser --login "$FLAKE_USER" -c "$RERUN_CMD"
          fi
        else
          exec sudo --login --user "$FLAKE_USER" -- bash "$RERUN" "$@"
        fi
        ;;
      *)
        echo "错误：已选择不创建用户。如需以 ${CURRENT_USER} 使用本仓库：" >&2
        echo "      编辑 meta.json 的 username 为 \"${CURRENT_USER}\"（单点定义），然后重新运行本脚本（target 按架构自动选择，无需传参）。" >&2
        exit 1
        ;;
    esac
  else
    echo "错误：当前用户 ${CURRENT_USER} 与 meta.json 定义的 username ${FLAKE_USER} 不一致（非交互终端，或既非 root 又无可用 sudo，无法询问建号）。" >&2
    echo "      如需以 ${CURRENT_USER} 使用本仓库：编辑 meta.json 的 username 为 \"${CURRENT_USER}\"（单点定义），" >&2
    echo "      然后重新运行本脚本（target 按架构自动选择，无需传参）；" >&2
    echo "      或由管理员创建用户 ${FLAKE_USER}（useradd -m）并以其登录重跑。" >&2
    exit 1
  fi
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
    # shellcheck disable=SC1091  # 运行时才存在的已知 nix profile 路径，静态检查无法跟随
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
# 2/7 配置国内镜像 + 社区缓存（cachix）
#     multi ：写 /etc/nix/nix.custom.conf 的 trusted-substituters / trusted-public-keys
#             并让 nix.conf include（daemon 侧授权，用户级 substituters 才会被多用户 daemon 接受）
#     single：无 daemon，用户级 nix.conf 的 substituters + 公钥直接生效，无需任何授权
#     幂等：两种模式均已配置时跳过；用户 nix.conf 已是 HM 托管 symlink 时不追加（nix-cn.nix 接管同一列表）
# ---------------------------------------------------------------------------
log "2/7 配置国内镜像（${NIX_INSTALL_MODE}-user）"
# 列表/公钥单源：repo 根 meta.json（home/nix-cn.nix 与 modules/fix-network.nix 读同一份）
# cachix 补官方 Hydra 常规任务不构建的路径（如 2026-09 曾全缓存 404 的 rainbow-delimiters-nvim）；
# 列表自带 cache.nixos.org（官方源默认已受信，trusted-substituters 里重复列出无害）
TRUSTED_SUBSTITUTERS="$(sed -n 's/.*"substituters": *"\([^"]*\)".*/\1/p' "$REPO_ROOT/meta.json" | head -n 1)"
CACHIX_PUBLIC_KEY="$(sed -n 's/.*"nixCommunityCachixKey": *"\([^"]*\)".*/\1/p' "$REPO_ROOT/meta.json" | head -n 1)"
[ -n "$TRUSTED_SUBSTITUTERS" ] && [ -n "$CACHIX_PUBLIC_KEY" ] || { echo "错误：无法从 meta.json 解析 substituters / nixCommunityCachixKey（文件缺失或格式变化）。" >&2; exit 1; }
if [ "$NIX_INSTALL_MODE" = "multi" ]; then
  NIX_CUSTOM_CONF="/etc/nix/nix.custom.conf"
  NIX_SYSTEM_CONF="/etc/nix/nix.conf"
  if [ -f "$NIX_CUSTOM_CONF" ] && sudo grep -q "nix-community.cachix.org" "$NIX_CUSTOM_CONF"; then
    echo "    已配置国内镜像与社区缓存信任，跳过"
  else
    sudo mkdir -p /etc/nix
    if [ -f "$NIX_CUSTOM_CONF" ] && sudo grep -q '^trusted-substituters' "$NIX_CUSTOM_CONF"; then
      sudo sed -i "s|^trusted-substituters = .*|trusted-substituters = $TRUSTED_SUBSTITUTERS|" "$NIX_CUSTOM_CONF"
    else
      printf 'trusted-substituters = %s\n' "$TRUSTED_SUBSTITUTERS" | sudo tee -a "$NIX_CUSTOM_CONF" > /dev/null
    fi
    # extra- 前缀 = 追加，保证内置的 cache.nixos.org-1 与安装器写入的其他 key 不被顶掉
    if ! sudo grep -q "nix-community.cachix.org-1" "$NIX_CUSTOM_CONF"; then
      printf 'extra-trusted-public-keys = %s\n' "$CACHIX_PUBLIC_KEY" | sudo tee -a "$NIX_CUSTOM_CONF" > /dev/null
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
  else
    if [ -f "$NIX_CONF" ] && grep -q '^substituters' "$NIX_CONF"; then
      echo "    用户级 substituters 已配置，跳过"
    else
      echo "substituters = $TRUSTED_SUBSTITUTERS" >> "$NIX_CONF"
      echo "    已写入用户级 substituters（$NIX_CONF）"
    fi
    # 单用户无 daemon，公钥写在用户级 nix.conf 里直接生效（不会触发受限设置警告）
    if ! grep -q "nix-community.cachix.org-1" "$NIX_CONF" 2>/dev/null; then
      echo "extra-trusted-public-keys = $CACHIX_PUBLIC_KEY" >> "$NIX_CONF"
      echo "    已写入社区缓存公钥（$NIX_CONF）"
    fi
  fi
  # 本次会话立即生效（后续 nix profile install / home-manager 拉包直接走国内镜像）
  export NIX_CONFIG="substituters = $TRUSTED_SUBSTITUTERS
extra-trusted-public-keys = $CACHIX_PUBLIC_KEY"
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

# 激活后自检（fail-loud）：HM 接管 bash 登录链后，单用户安装在用户 dotfile 里写下的
# PATH 钩子会随之失效 —— standalone-linux.nix 的 home.sessionPath 负责补上；此处用
# 干净环境起一个 bash 登录 shell 验证 nix 仍可用，防止同类回归静默通过。
# （zsh/fish 走 rc 追加段、仅交互会话生效，非交互登录链测不了，不在本检查范围。）
if ! env -i HOME="$HOME" USER="$(id -un)" LOGNAME="$(id -un)" TERM="${TERM:-xterm}" \
     /bin/bash -lc 'command -v nix >/dev/null 2>&1'; then
  echo "错误：激活后新 bash 登录 shell 的 PATH 中找不到 nix。" >&2
  echo "      检查 home/standalone-linux.nix 的 home.sessionPath 是否包含 ~/.nix-profile/bin。" >&2
  exit 1
fi
echo "    自检通过：干净 bash 登录 shell 中 nix 可用（PATH 钩子在 HM 接管 dotfile 后仍有效）"

cat <<EOF

完成。请打开新 shell（或 exec bash -l）以加载新环境。

  · 安装模式：${NIX_INSTALL_MODE}-user$( [ "$NIX_INSTALL_MODE" = "single" ] && echo '（无 daemon：镜像/ flakes/token 均在用户级 nix.conf；升级 nix 本体请重跑官方安装器）' )
  · 被接管文件的原版备份在：~/*.bak-${TS} 与 ~/.profile.backup
  · ⚠️ programs.ssh 用 enableDefaultConfig=false，新 ~/.ssh/config 只含 HM 定义的 host。
    如果你旧 ssh config（备份在 ~/.ssh/config.bak-${TS}）里还有别的 host，需要手动合并回
    home/common.nix 的 programs.ssh。
  · 实际使用 zsh / fish 时（登录 shell 是它，或对应 rc 文件已存在）：激活会幂等追加
    带守卫的 HM 会话环境加载段（fish 无 bass 时仅加 PATH，完整变量需 bash/zsh 或安装 bass）；
    bash-only 的机器不会凭空创建这些 rc 文件。
  · 以后更新配置： cd ${REPO_ROOT} && home-manager switch --flake .#${FLAKE_TARGET}
EOF
