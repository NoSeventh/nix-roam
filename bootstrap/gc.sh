#!/usr/bin/env bash
# 手动清理 Nix 旧世代与无引用的 store 路径；兼容 macOS 自带 Bash 3.2。
set -euo pipefail

usage() {
  cat <<'EOF'
用法：bash bootstrap/gc.sh [选项]

  --older-than Nd  清理超过 N 天的旧世代，默认 14d（N 必须为正整数）
  --all            清理全部非当前世代
  --system         在用户清理之后，也以 root 清理系统/root 的旧世代
  --dry-run        仅打印将运行的命令，不删除世代、不执行垃圾回收
  -h, --help       显示帮助

请以普通用户运行，脚本在需要时自行调用 sudo。
NixOS 自动启用 --system；普通 Linux / WSL / macOS 默认清理用户环境。
macOS 使用 nix-darwin 时，可加 --system 清理其系统旧世代。
删除的世代将无法直接回滚；仍被当前环境或其他 GC 根引用的包会保留。
本脚本不更新 NixOS / nix-darwin 的引导菜单，也不修改自动清理配置。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

# --- 1. 参数 ---
period=14d
policy=age
policy_set=false
system_gc=false
dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --older-than)
      [ "$#" -ge 2 ] || die '--older-than 需要参数，例如 30d'
      [ "$policy_set" = false ] || die '--older-than 与 --all 只能指定一次且不能混用'
      [[ "$2" =~ ^[1-9][0-9]*d$ ]] || die '保留期限必须是正整数天，例如 14d'
      period="$2"
      policy_set=true
      shift 2
      ;;
    --all)
      [ "$policy_set" = false ] || die '--older-than 与 --all 只能指定一次且不能混用'
      policy=all
      policy_set=true
      shift
      ;;
    --system) system_gc=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1（使用 --help 查看用法）" ;;
  esac
done

# --- 2. 检测实际宿主环境 ---
kernel="$(uname -s)"
host_details="$(uname -a)"
case "$kernel" in
  Linux)
    os_name=Linux
    if [ -r /etc/os-release ]; then
      os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-Linux}")"
    fi
    if [ -e /etc/NIXOS ]; then
      environment=NixOS
      system_gc=true
    elif [[ "$host_details" == *[Mm]icrosoft* ]]; then
      environment="$os_name / WSL（独立 Nix）"
    else
      environment="$os_name（独立 Nix）"
    fi
    ;;
  Darwin) environment='macOS / Darwin' ;;
  *) die "不支持的系统：$kernel" ;;
esac
printf '当前环境：%s\n' "$environment"

if [ "${SUDO_USER:-root}" != root ] && [ "$EUID" -eq 0 ]; then
  die '请去掉外层 sudo，以便先清理你自己的 Home Manager 世代；需要时脚本会调用 sudo'
fi

# 不依赖 sudo 的 PATH；也兼容尚未加载 Nix shell 环境的终端。
gc_bin="$(type -P nix-collect-garbage || true)"
if [ -z "$gc_bin" ]; then
  for candidate in \
    "$HOME/.nix-profile/bin/nix-collect-garbage" \
    /nix/var/nix/profiles/default/bin/nix-collect-garbage \
    /run/current-system/sw/bin/nix-collect-garbage; do
    if [ -x "$candidate" ]; then
      gc_bin="$candidate"
      break
    fi
  done
fi
[ -n "$gc_bin" ] || die '未找到 nix-collect-garbage，请先安装 Nix 或加载 Nix 环境'
if [ "$system_gc" = true ] && [ "$EUID" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die '系统清理需要 sudo'
fi

# --- 3. 先用户、后系统；预览模式不调用任何清理命令 ---
gc_args=(--delete-older-than "$period")
if [ "$policy" = all ]; then
  gc_args=(--delete-old)
fi
run() {
  printf '执行：'
  printf ' %q' "$@"
  printf '\n'
  if [ "$dry_run" = false ]; then
    "$@"
  fi
}

printf '旧世代删除后无法直接回滚；仍被引用的包会保留。\n'
if [ "$dry_run" = true ]; then
  printf '预览模式：仅显示命令，不估算可释放空间。\n'
fi
run "$gc_bin" "${gc_args[@]}"
if [ "$system_gc" = true ] && [ "$EUID" -ne 0 ]; then
  run sudo -H -- "$gc_bin" "${gc_args[@]}"
fi
