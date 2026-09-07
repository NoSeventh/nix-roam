#!/usr/bin/env bash
# bootstrap/nixos.sh
#
# NixOS 侧引导脚本，与 bootstrap/linux.sh（standalone Linux）、bootstrap/darwin.sh（macOS）平行。
# 两条链路（自动检测，也可用子命令强制指定）：
#   install —— NixOS 安装 ISO 中全新安装实体机：
#       配置镜像 → 可选 token → 克隆仓库 → 生成硬件配置 → nixos-install → 设置用户密码
#   adopt   —— 已运行的 NixOS / 刚导入的 NixOS-WSL 上采用本仓库：
#       配置镜像 → 可选 token → 备份旧配置并克隆仓库 → 对齐 stateVersion → nixos-rebuild switch
#
# 用法（必须以 root 运行）：
#     bash bootstrap/nixos.sh                      # 自动检测模式与 flake 目标
#     bash bootstrap/nixos.sh install              # 强制全新安装（ISO 内，目标盘挂载在 /mnt）
#     bash bootstrap/nixos.sh adopt                # 强制迁移（已安装的 NixOS / NixOS-WSL）
#     bash bootstrap/nixos.sh adopt --target wsl   # 覆盖自动检测的 flake 目标
#
# install 不做分区/格式化，请先自行完成并挂载（systemd-boot 布局参考）：
#     parted /dev/nvme0n1 -- mklabel gpt
#     parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 513MiB
#     parted /dev/nvme0n1 -- set 1 esp on
#     parted /dev/nvme0n1 -- mkpart primary ext4 513MiB 100%
#     mkfs.fat -F 32 /dev/nvme0n1p1
#     mkfs.ext4 /dev/nvme0n1p2
#     mount /dev/nvme0n1p2 /mnt
#     mkdir -p /mnt/boot && mount /dev/nvme0n1p1 /mnt/boot
#
# 幂等：可安全重复运行。镜像/token 已配置则跳过；仓库已克隆则复用；
# install 每次重新生成硬件配置（真实反映 /mnt 当前挂载状态）。
set -euo pipefail

usage() {
  cat <<'EOF'
用法：bash bootstrap/nixos.sh [命令] [选项]

命令（默认自动检测：/etc/NIXOS 存在则 adopt，否则视为安装 ISO 中的 install）：
  install              全新安装：在 NixOS 安装 ISO 中以 root 运行，目标盘已挂载 /mnt
  adopt                迁移：在已运行的 NixOS / NixOS-WSL 上采用本仓库并切换

选项：
  --target nixos|wsl   指定 flake 目标（默认自动检测；install 固定为 nixos）
  -h, --help           显示帮助

必须以 root 运行（sudo bash bootstrap/nixos.sh）。
install 不做分区/格式化：分区与挂载（含 ESP → /mnt/boot）请先自行完成，参考命令见脚本头部注释。
WSL 没有 install 场景：先按 NixOS-WSL 官方文档导入发行版，再运行 adopt。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 0. 参数与守卫 ---
MODE_ARG=""
TARGET_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    install|adopt)
      [ -z "$MODE_ARG" ] || die "命令只能指定一次：$1"
      MODE_ARG="$1"
      shift
      ;;
    --target)
      [ "$#" -ge 2 ] || die '--target 需要参数：nixos 或 wsl'
      case "$2" in
        nixos|wsl) TARGET_ARG="$2" ;;
        *) die '--target 只支持 nixos 或 wsl' ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1（使用 --help 查看用法）" ;;
  esac
done

[ "$(uname -s)" = "Linux" ] || die "此脚本仅用于 NixOS；普通 Linux/WSL 请用 bootstrap/linux.sh，macOS 请用 bootstrap/darwin.sh。"
[ "$(uname -m)" = "x86_64" ] || die "flake 仅提供 x86_64-linux 的 NixOS 输出。"
[ "$EUID" -eq 0 ] || die "请以 root 运行（sudo bash bootstrap/nixos.sh）；install 与 nixos-rebuild 都需要 root。"

# 模式自动检测：/etc/NIXOS 是「已安装 NixOS」的标志（安装 ISO 与普通 Linux 上不存在）
if [ -z "$MODE_ARG" ]; then
  if [ -e /etc/NIXOS ]; then
    MODE=adopt
  else
    MODE=install
  fi
else
  MODE="$MODE_ARG"
fi

# flake 目标自动检测：install 只对应实体机；adopt 按 WSL 内核特征区分
if [ -n "$TARGET_ARG" ]; then
  TARGET="$TARGET_ARG"
elif [ "$MODE" = install ]; then
  TARGET=nixos
elif grep -qi microsoft /proc/version 2>/dev/null; then
  TARGET=wsl
else
  TARGET=nixos
fi
if [ "$MODE" = install ] && [ "$TARGET" = wsl ]; then
  die "install 场景没有 WSL 目标：WSL 请先按官方文档导入发行版，再运行 adopt。"
fi

if [ "$MODE" = install ]; then
  if ! mountpoint -q /mnt 2>/dev/null && ! grep -qs ' /mnt ' /proc/mounts; then
    die "install 需要目标盘已挂载到 /mnt（ESP 挂 /mnt/boot）；分区参考命令见脚本头部注释。普通 Linux/WSL 请改用 bootstrap/linux.sh。"
  fi
  have nixos-install || die "未找到 nixos-install，请在 NixOS 安装 ISO 中以 root 运行本脚本。"
else
  [ -e /etc/NIXOS ] || die "adopt 需要在已运行的 NixOS / NixOS-WSL 上执行；全新安装请用 install 子命令。"
fi

if [ "$MODE" = install ]; then
  CLONE_DIR="/mnt/etc/nixos"
else
  CLONE_DIR="/etc/nixos"
fi
TS="$(date +%Y%m%d-%H%M%S)"
log "模式：${MODE}（flake 目标：${TARGET}，仓库位置：${CLONE_DIR}）"

# ---------------------------------------------------------------------------
# 1/7 配置国内镜像信任
#     写 daemon 侧 nix.custom.conf（列表与跳过检查同 linux/darwin 脚本），
#     并导出 NIX_CONFIG 让脚本内所有 nix 调用立即走国内缓存 ——
#     nix.settings 托管的 /etc/nix/nix.conf 是指向 store 的 symlink，无法追加 include，
#     此时镜像仍经 NIX_CONFIG 生效（root 客户端默认受信，可自带 substituters）。
#     install 模式下 ISO 是内存系统，重启即失；adopt 模式切换完成后由
#     modules/fix-network.nix → home/nix-cn.nix 接管 daemon 配置（单一配置源）。
# ---------------------------------------------------------------------------
log "1/7 配置国内镜像信任"
NIX_CUSTOM_CONF="/etc/nix/nix.custom.conf"
NIX_SYSTEM_CONF="/etc/nix/nix.conf"
TRUSTED_SUBSTITUTERS="https://mirror.nju.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://mirror.sjtu.edu.cn/nix-channels/store"
if [ -f "$NIX_CUSTOM_CONF" ] && grep -q "mirror.nju.edu.cn/nix-channels/store" "$NIX_CUSTOM_CONF"; then
  echo "    已配置国内镜像信任，跳过"
else
  mkdir -p /etc/nix
  if [ -f "$NIX_CUSTOM_CONF" ] && grep -q '^trusted-substituters' "$NIX_CUSTOM_CONF"; then
    sed -i "s|^trusted-substituters = .*|trusted-substituters = $TRUSTED_SUBSTITUTERS|" "$NIX_CUSTOM_CONF"
  else
    printf 'trusted-substituters = %s\n' "$TRUSTED_SUBSTITUTERS" >> "$NIX_CUSTOM_CONF"
  fi
  echo "    已写入 $NIX_CUSTOM_CONF"
fi
if [ -L "$NIX_SYSTEM_CONF" ]; then
  echo "    $NIX_SYSTEM_CONF 是 NixOS 托管的 symlink（nix.settings），不追加 include；镜像经下方 NIX_CONFIG 生效"
elif [ ! -f "$NIX_SYSTEM_CONF" ] || ! grep -Eq '^!include[[:space:]]+(nix\.custom\.conf|/etc/nix/nix\.custom\.conf)$' "$NIX_SYSTEM_CONF"; then
  printf '\n!include /etc/nix/nix.custom.conf\n' >> "$NIX_SYSTEM_CONF"
  echo "    已让 $NIX_SYSTEM_CONF 加载 nix.custom.conf"
fi
SUBSTITUTERS_LINE="substituters = ${TRUSTED_SUBSTITUTERS} https://cache.nixos.org"

# ---------------------------------------------------------------------------
# 2/7 配置 GitHub token（可选）
#     与 linux.sh 的差异：NixOS 侧 nixos-install / nixos-rebuild 以 root 走 daemon，
#     daemon 不读用户级 token 文件，因此 token 行写入 daemon 侧 nix.custom.conf
#     （权限 0600，不进仓库与 store）。install 模式下随 ISO 重启即丢；
#     adopt 模式切换后 nix.conf 被系统接管，token 行不再生效，属预期。
# ---------------------------------------------------------------------------
log "2/7 配置 GitHub token（缓解 API 限流）"
TOKEN_LINE=""
if [ -t 0 ]; then
  read -r -s -p "    粘贴新 GitHub token（回车确认，留空沿用旧值）: " GITHUB_TOKEN
  echo
  if [ -n "$GITHUB_TOKEN" ]; then
    if [[ "$GITHUB_TOKEN" =~ [[:space:]] ]]; then
      die "GitHub token 不应包含空白字符。"
    fi
    if [ -f "$NIX_CUSTOM_CONF" ] && grep -q '^access-tokens' "$NIX_CUSTOM_CONF"; then
      sed -i "s|^access-tokens = .*|access-tokens = github.com=${GITHUB_TOKEN}|" "$NIX_CUSTOM_CONF"
    else
      printf 'access-tokens = github.com=%s\n' "$GITHUB_TOKEN" >> "$NIX_CUSTOM_CONF"
    fi
    chmod 600 "$NIX_CUSTOM_CONF"
    echo "    已写入 $NIX_CUSTOM_CONF（权限 0600，仅本机引导期生效）"
    unset GITHUB_TOKEN
  elif [ -f "$NIX_CUSTOM_CONF" ] && grep -q '^access-tokens' "$NIX_CUSTOM_CONF"; then
    echo "    未输入新 token，继续沿用旧值"
  else
    echo "    未输入 token，当前保持未配置"
  fi
else
  echo "    当前非交互终端，保留现有 token 配置"
fi
if [ -f "$NIX_CUSTOM_CONF" ]; then
  TOKEN_LINE="$(grep '^access-tokens' "$NIX_CUSTOM_CONF" || true)"
fi

# 本脚本内所有 nix 调用（含 nixos-install / nixos-rebuild 的子进程）立即生效的客户端配置
export NIX_CONFIG="${SUBSTITUTERS_LINE}${TOKEN_LINE:+
${TOKEN_LINE}}"

# ---------------------------------------------------------------------------
# 3/7 准备仓库
#     install → /mnt/etc/nixos（装完即系统配置目录）；adopt → /etc/nixos。
#     旧的非本仓库配置整体备份；ISO / 全新 NixOS-WSL 没有 git 时借 nixpkgs 通道装一份。
# ---------------------------------------------------------------------------
log "3/7 准备仓库（${CLONE_DIR}）"
if ! have git; then
  nix-env -f '<nixpkgs>' -iA git || die "通过 <nixpkgs> 通道安装 git 失败，请手动安装后重试"
fi
if [ -d "$CLONE_DIR/.git" ] && git -C "$CLONE_DIR" config --get remote.origin.url 2>/dev/null | grep -qE 'nixos-niri-noctalia|nix-roam'; then
  echo "    ${CLONE_DIR} 已是本仓库克隆，复用；如需更新请自行 git pull --ff-only"
else
  if [ -e "$CLONE_DIR" ]; then
    mv "$CLONE_DIR" "${CLONE_DIR}.bak-${TS}"
    echo "    已备份原有配置：${CLONE_DIR} -> ${CLONE_DIR}.bak-${TS}"
  fi
  git clone https://gitee.com/qihaoxu/nixos-niri-noctalia.git "$CLONE_DIR"
fi

# ---------------------------------------------------------------------------
# 4/7 生成硬件配置（install）/ 对齐 stateVersion（adopt）
# ---------------------------------------------------------------------------
if [ "$MODE" = install ]; then
  log "4/7 生成硬件配置（nixos-generate-config）"
  # 生成到仓库根的 hardware-configuration.nix —— 正是 .gitignore 已忽略的误生成路径，用完即移
  nixos-generate-config --root /mnt
  GEN_HW="$CLONE_DIR/hardware-configuration.nix"
  [ -f "$GEN_HW" ] || die "nixos-generate-config 未生成 $GEN_HW"
  HW_TRACKED="$CLONE_DIR/hosts/nixos/hardware-configuration.nix"
  if [ -f "$HW_TRACKED" ]; then
    cp -a "$HW_TRACKED" "$HW_TRACKED.bak-${TS}"
    echo "    原硬件配置备份：$HW_TRACKED.bak-${TS}"
    echo "    新旧差异："
    diff -u "$HW_TRACKED.bak-${TS}" "$GEN_HW" || true
  fi
  mv "$GEN_HW" "$HW_TRACKED"
  rm -f "$CLONE_DIR/configuration.nix" # 顺带生成的旧式入口，flake 布局用不到
  if ! grep -q 'fileSystems\."/boot"' "$HW_TRACKED"; then
    die "新生成的硬件配置缺少 /boot（ESP）挂载点：systemd-boot 需要它。请把 ESP 挂到 /mnt/boot 后重跑本脚本（幂等）。"
  fi
  echo "    硬件配置已更新：$HW_TRACKED"
  echo "    提示：UUID 变化属重新分区后的正常现象；若目标其实是另一台机器，请改走 AGENTS.md 的新机器流程。"
else
  log "4/7 对齐 system.stateVersion"
  # /etc/NIXOS 记录初次安装时的 NixOS 版本，取前两段即当时的 stateVersion
  CURRENT_SV="$(tr -d '[:space:]' < /etc/NIXOS 2>/dev/null | cut -d. -f1-2 || true)"
  SHARED_SV="$(sed -n 's/^ *system\.stateVersion = "\([^"]*\)";/\1/p' "$CLONE_DIR/profiles/nixos-base.nix" | head -n 1)"
  : "${SHARED_SV:=26.05}"
  if [ -z "$CURRENT_SV" ]; then
    echo "    无法读取 /etc/NIXOS 的原系统版本，按共享值 ${SHARED_SV} 继续"
  elif [ "$CURRENT_SV" != "$SHARED_SV" ]; then
    cat >&2 <<EOF
    ⚠️  目标系统原 stateVersion 为 ${CURRENT_SV}，本仓库共享值为 ${SHARED_SV}（profiles/nixos-base.nix）。
        stateVersion 不应随配置迁移而变化：请先在主机入口（hosts/<hostname>/default.nix）加
        system.stateVersion = lib.mkForce "${CURRENT_SV}"; 保留原值后重跑本脚本（见 AGENTS.md / README）。
EOF
    if [ -t 0 ]; then
      read -r -p "    明知风险仍要继续吗？[y/N] " ANSWER
      case "$ANSWER" in
        y|Y) echo "    继续切换（stateVersion 差异风险自负）" ;;
        *) die "已中止：请先对齐 stateVersion。" ;;
      esac
    else
      die "非交互终端且 stateVersion 不一致，已中止。"
    fi
  else
    echo "    原系统 stateVersion：${CURRENT_SV}，与共享值 ${SHARED_SV} 一致，继续"
  fi
fi

# ---------------------------------------------------------------------------
# 5/7 安装（install）/ 切换（adopt）
#     adopt：系统与集成 Home Manager 一起激活，无需单独运行 home-manager。
# ---------------------------------------------------------------------------
if [ "$MODE" = install ]; then
  log "5/7 安装 NixOS（nixos-install → .#nixos）"
  # 结束时会交互式提示设置 root 密码：保留作 TTY 救急通道，日常登录用 xuqihao
  nixos-install --root /mnt --flake "${CLONE_DIR}#nixos"
else
  log "5/7 切换系统配置（nixos-rebuild switch → .#${TARGET}）"
  nixos-rebuild switch --flake "${CLONE_DIR}#${TARGET}"
fi

# ---------------------------------------------------------------------------
# 6/7 设置用户密码
#     仓库配置未给 xuqihao 定义任何密码字段（账号为锁定状态）：
#     install 实体机不设置则无法登录 GDM；WSL 免密登录、adopt 沿用既有账号，均跳过。
# ---------------------------------------------------------------------------
log "6/7 设置用户密码"
if [ "$MODE" = install ] && [ "$TARGET" = nixos ]; then
  nixos-enter --root /mnt -c 'passwd xuqihao'
else
  echo "    当前场景无需设置（WSL 免密登录；adopt 沿用既有账号），跳过"
fi

# ---------------------------------------------------------------------------
# 7/7 收尾提醒
# ---------------------------------------------------------------------------
log "7/7 完成"
if [ "$MODE" = install ]; then
  cat <<EOF

完成。拔掉安装介质后 reboot 进入新系统。

  · xuqihao 的登录密码已设置；root 密码在 nixos-install 结尾设置（TTY 救急用）。
  · hosts/nixos/hardware-configuration.nix 已按本次磁盘重新生成（原版备份在同目录 *.bak-${TS}），
    确认无误后请提交回 Gitee，保持仓库可复现构建。
  · 以后更新配置：cd ${CLONE_DIR} && sudo nixos-rebuild switch --flake .#nixos
EOF
else
  cat <<EOF

完成。系统与集成 Home Manager 已一起切换。

  · 以 xuqihao 注销重登（WSL：从 Windows 重新进入发行版）后，Home Manager 用户配置生效。
  · 原配置目录（若有被替换）备份在：${CLONE_DIR}.bak-${TS}
  · 以后更新配置：cd ${CLONE_DIR} && sudo nixos-rebuild switch --flake .#${TARGET}
EOF
fi
if [ "$TARGET" = nixos ]; then
  cat <<EOF

  · ⚠️ Hermes Agent 需要目标机器自行提供 /etc/hermes/env（API 密钥，见 modules/desktop/agents.nix）；
    该文件不随仓库分发，缺失时服务无法以有效凭据启动。
EOF
fi
