#!/usr/bin/env bash
# roam — nix-roam 统一 CLI 入口
#
# 与 bootstrap/bootstrap.sh 同款宿主探测约定（入口级重复在本仓库是刻意允许的）：
# /etc/NIXOS 存在 → NixOS；否则 standalone Home Manager。
#   roam switch [args...]  NixOS → nh os switch --diff always .（WSL 下失败时打印
#                          stc-exit-4 补救提示）；standalone → home-manager switch
#                          .#<系统名输出>（按求值平台选输出 + meta.json 用户守卫）
#   roam gc [args...]      原样透传 bootstrap/gc.sh
#   roam check [--build] [目标]
#                          CI 两层验证的本地等价物：默认 nix eval --raw 当前宿主目标的
#                          drvPath（第一层）；--build 时 nix build --no-link（第二层）。
#                          目标可显式指定：nixos / wsl / x86_64-linux / aarch64-linux /
#                          aarch64-darwin（跨主机核对其它输出，仅求值语义）
#   roam update [输入名...|--all]
#                          nix flake update + flake.lock 差异摘要；提交与切换保持手动。
#                          缺省交互选择要更新的输入（回车/EOF=全部），显式输入名或
#                          --all 跳过交互
#   roam info              只读打印宿主探测结论（环境 / 用户守卫 / 将选中的输出）
#
# 需在本仓库检出目录下运行（flake 位置参数 '.' 按 cwd 解析）。
# 经 packages/roam.nix（writeShellApplication）挂入 packages/cli-dev.nix 四个安装点，
# 也可直接 `bash packages/roam.sh` 调试。保持 macOS Bash 3.2 兼容（无关联数组等 bash4 特性）。
set -euo pipefail

usage() {
  cat <<'EOF'
用法：roam <子命令> [参数]（本仓库统一 CLI；需在仓库检出目录下运行）

  switch [args...]   按宿主切换：NixOS → nh os switch --diff always .
                     standalone → home-manager switch .#<系统输出>（含用户守卫）
  gc [args...]       透传 bootstrap/gc.sh（--older-than Nd / --all / --system / --dry-run）
  check [--build] [目标]
                     验证目标：默认求值（nix eval --raw …drvPath，CI 第一层）；
                     --build 时构建（nix build --no-link，CI 第二层）。
                     目标：nixos wsl x86_64-linux aarch64-linux aarch64-darwin（缺省=当前宿主）
  update [输入名...|--all]
                     nix flake update 并显示 flake.lock 差异；提交与切换仍手动。
                     缺省时列出 flake 输入供选择：回车（或非交互 EOF）=全部；
                     显式输入名可多个只更新它们；--all 跳过选择直接全量
  info               只读打印宿主探测结论（NixOS/standalone、架构、用户守卫、目标输出）
  help               显示本帮助
EOF
}

die() { printf 'roam: 错误：%s\n' "$*" >&2; exit 1; }

# --- 1. 宿主与仓库探测 ---
kernel="$(uname -s)"

is_wsl() { uname -r | grep -qi microsoft; }
is_nixos() { [ -f /etc/NIXOS ]; }

repo_check() {
  [ -f flake.nix ] && [ -f meta.json ] \
    || die "当前目录不是本仓库检出（缺 flake.nix / meta.json）；请 cd 到检出目录（flake 位置参数 '.' 按 cwd 解析）"
}

# 与 bootstrap 脚本同款 sed（格式由本仓库自持）；解析失败即中止，无硬编码回落。
meta_username() {
  local u
  u="$(sed -n 's/.*"username": *"\([^"]*\)".*/\1/p' meta.json | head -n 1)"
  [ -n "$u" ] || die "无法从 meta.json 解析 username（文件缺失或格式变化）"
  printf '%s' "$u"
}

# standalone 输出名即系统名（flake.nix 显式输出，不随用户名变化）
standalone_target() {
  case "$kernel" in
    Darwin)
      [ "$(uname -m)" = arm64 ] || die "macOS 仅提供 aarch64-darwin 输出（Intel Mac 不受支持）"
      printf '%s' aarch64-darwin
      ;;
    Linux)
      case "$(uname -m)" in
        x86_64) printf '%s' x86_64-linux ;;
        aarch64 | arm64) printf '%s' aarch64-linux ;;
        *) die "不支持的架构：$(uname -m)（standalone 输出仅 x86_64-linux / aarch64-linux / aarch64-darwin）" ;;
      esac
      ;;
    *) die "不支持的系统：$kernel" ;;
  esac
}

# 目录名 = hostname = 输出属性名（本仓库约定，roam switch 的 nh 后端依赖同一约定）
nixos_output() {
  local h
  h="$(uname -n)"
  printf 'nixosConfigurations.%s' "${h%%.*}"
}

# --- 2. 子命令 ---
cmd_switch() {
  local rc target u
  repo_check
  if is_nixos; then
    command -v nh >/dev/null 2>&1 \
      || die "未找到 nh（NixOS 侧由 profiles/nixos-base.nix 的 programs.nh.enable 提供）"
    set +e
    nh os switch --diff always . "$@"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && is_wsl; then
      printf 'roam: nh 退出码 %s。NixOS-WSL 下 stc exit 4 时世代可能未落盘：\n' "$rc" >&2
      printf '  Windows 侧 wsl --shutdown 后重试；或 sudo nixos-rebuild switch --flake .#wsl 补落世代（见 AGENTS.md）\n' >&2
    fi
    return "$rc"
  fi
  u="$(meta_username)"
  [ "$(id -un)" = "$u" ] \
    || die "当前用户是 $(id -un)，不是 $u；拒绝切换（本地用户名在 meta.json 单点定义）"
  target="$(standalone_target)"
  command -v home-manager >/dev/null 2>&1 \
    || die "未找到 home-manager（standalone 激活后应位于 ~/.nix-profile/bin）"
  exec home-manager switch --flake ".#${target}" "$@"
}

cmd_gc() {
  repo_check
  [ -f bootstrap/gc.sh ] || die "检出中缺少 bootstrap/gc.sh"
  exec bash "$PWD/bootstrap/gc.sh" "$@"
}

cmd_check() {
  local build=false target='' attr=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --build) build=true ;;
      -*) die "check: 未知选项：$1" ;;
      *)
        [ -z "$target" ] || die "check: 目标只能指定一个"
        target="$1"
        ;;
    esac
    shift
  done
  repo_check
  if [ -n "$target" ]; then
    case "$target" in
      nixos | wsl) attr="nixosConfigurations.${target}.config.system.build.toplevel" ;;
      x86_64-linux | aarch64-linux | aarch64-darwin)
        attr="homeConfigurations.${target}.activationPackage"
        ;;
      *) die "未知目标：$target（可用：nixos wsl x86_64-linux aarch64-linux aarch64-darwin，缺省=当前宿主）" ;;
    esac
  elif is_nixos; then
    attr="$(nixos_output).config.system.build.toplevel"
  else
    attr="homeConfigurations.$(standalone_target).activationPackage"
  fi
  if [ "$build" = true ]; then
    printf 'roam check: 构建 .#%s\n' "$attr"
    nix build --no-link ".#${attr}"
  else
    printf 'roam check: 求值 .#%s\n' "$attr"
    nix eval --raw ".#${attr}.drvPath"
    printf '\n'
  fi
}

# 列出 flake.lock 顶层输入供选择（菜单走 stderr，选定的输入名走 stdout，空输出=全部）。
# EOF / 无 jq / 无 flake.lock 一律回落「全部」（默认全选）；无效输入则中止。
choose_inputs() {
  local input_names reply tok name nm n idx picked='' all_names='' rev date
  command -v jq >/dev/null 2>&1 || { printf 'roam: 无 jq，跳过选择，按全部输入更新\n' >&2; return 0; }
  [ -f flake.lock ] || { printf 'roam: 无 flake.lock，按全部输入更新\n' >&2; return 0; }
  input_names="$(jq -r '
    .nodes as $nodes | $nodes.root.inputs | to_entries[] |
    .key as $k | .value as $v |
    (if ($v|type)=="string" then (try ($nodes[$v].locked.rev // "-") catch "-") else "-" end) as $rev |
    (if ($v|type)=="string" then (try ($nodes[$v].locked.lastModified | localtime | strftime("%Y-%m-%d")) catch "-") else "-" end) as $date |
    "\($k)\t\(if $rev=="-" then "-" else $rev[0:7] end)\t\($date)"
  ' flake.lock)" || return 0
  printf 'flake 输入（flake.lock 当前锁定）:\n' >&2
  idx=0
  while IFS=$'\t' read -r name rev date; do
    [ -n "$name" ] || continue
    idx=$((idx + 1))
    printf '  %d) %-16s %s  %s\n' "$idx" "$name" "$rev" "$date" >&2
    all_names="$all_names $name"
  done <<EOF
$input_names
EOF
  printf '选择要更新的输入：回车=全部；或输入编号/名称（空格或逗号分隔，如 1 3 / nixpkgs nixvim）: ' >&2
  read -r reply || return 0
  [ -n "$reply" ] || return 0
  # 用户回复里逗号与空格统一当分隔符；输入名本身不含空格（flake 输入名为标识符）
  # shellcheck disable=SC2086
  for tok in $(printf '%s' "$reply" | tr ',' ' '); do
    name=''
    case "$tok" in
      '' | *[!0-9]*) name="$tok" ;;
      *)
        # 纯数字：按编号取名字
        n=0
        # shellcheck disable=SC2086
        for nm in $all_names; do
          n=$((n + 1))
          if [ "$n" = "$tok" ]; then
            name="$nm"
            break
          fi
        done
        ;;
    esac
    if [ -z "$name" ]; then
      die "无法识别的选择：$tok"
    fi
    case " $all_names " in
      *" $name "*) : ;;
      *) die "未知输入：$name（可用：${all_names# }）" ;;
    esac
    case " $picked " in
      *" $name "*) : ;;
      *) picked="$picked $name" ;;
    esac
  done
  printf '%s' "${picked# }"
}

cmd_update() {
  local all=false names='' sel
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -a | --all) all=true ;;
      -*) die "update: 未知选项：$1" ;;
      *) names="$names $1" ;;
    esac
    shift
  done
  names="${names# }"
  if [ "$all" = true ] && [ -n "$names" ]; then
    die "update: --all 与输入名不能同时指定"
  fi
  repo_check
  if [ "$all" = false ] && [ -z "$names" ]; then
    sel="$(choose_inputs)"
    names="$sel"
  fi
  if [ -n "$names" ]; then
    printf 'roam update: 更新输入：%s\n' "$names"
    # 输入名经 flake.lock 白名单或用户显式给出，不含空格与通配
    # shellcheck disable=SC2086
    nix flake update $names
  else
    printf 'roam update: 更新全部输入\n'
    nix flake update
  fi
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --stat -- flake.lock || true
  fi
  printf 'roam: 请 review 并提交 flake.lock，再以 roam check / roam switch 验证受影响目标（nix-channel --update 不会更新 flake 依赖）\n'
}

cmd_info() {
  local kind target u current pretty
  pretty="$(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release 2>/dev/null | head -n 1)"
  [ -n "$pretty" ] || pretty="$kernel $(uname -r)"
  if is_nixos; then kind=NixOS; else kind='standalone Home Manager'; fi
  printf '系统        : %s\n' "$pretty"
  printf '内核        : %s\n' "$(uname -r)"
  printf 'WSL         : %s\n' "$(if is_wsl; then printf 是; else printf 否; fi)"
  printf '宿主类型    : %s\n' "$kind"
  printf '架构        : %s\n' "$(uname -m)"
  current="$(id -un)"
  printf '当前用户    : %s\n' "$current"
  if [ -f flake.nix ] && [ -f meta.json ]; then
    u="$(meta_username)"
    if [ "$current" = "$u" ]; then
      printf '用户守卫    : 通过（meta.json username=%s）\n' "$u"
    else
      printf '用户守卫    : 不通过（当前 %s ≠ meta.json %s，switch 将拒绝）\n' "$current" "$u"
    fi
  else
    printf '用户守卫    : 跳过（cwd 非本仓库检出）\n'
  fi
  if [ "$kind" = NixOS ]; then
    printf 'switch 目标 : nh os switch --diff always . → %s\n' "$(nixos_output)"
    printf 'check 目标  : %s.config.system.build.toplevel\n' "$(nixos_output)"
    if command -v nh >/dev/null 2>&1; then
      printf 'nh          : 可用\n'
    else
      printf 'nh          : 缺失（switch 将拒绝）\n'
    fi
  else
    target="$(standalone_target)"
    printf 'switch 目标 : home-manager switch --flake .#%s\n' "$target"
    printf 'check 目标  : homeConfigurations.%s.activationPackage\n' "$target"
    if command -v home-manager >/dev/null 2>&1; then
      printf 'home-manager: 可用\n'
    else
      printf 'home-manager: 缺失（switch 将拒绝）\n'
    fi
  fi
  printf '检出目录    : %s\n' "$PWD"
}

# --- 3. 分发 ---
cmd="${1:-help}"
if [ "$#" -gt 0 ]; then
  shift
fi
case "$cmd" in
  switch) cmd_switch "$@" ;;
  gc) cmd_gc "$@" ;;
  check) cmd_check "$@" ;;
  update) cmd_update "$@" ;;
  info) cmd_info "$@" ;;
  help | -h | --help) usage ;;
  *)
    printf 'roam: 未知子命令：%s\n\n' "$cmd" >&2
    usage >&2
    exit 1
    ;;
esac
