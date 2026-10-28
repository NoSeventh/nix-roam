#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034
usage() {
  cat <<'EOF'
用法：roam <子命令> [参数]（本仓库统一 CLI；rollback、gc、mnt、info 无需仓库检出目录）

  switch [args...]   按宿主切换：NixOS → nh os switch --diff always path:./.
                     standalone → nh home switch --diff always --configuration <系统输出> path:./.
                     （含用户守卫）；全程落日志到 ~/.local/state/nix-roam/switch-*.log
  status             漂移检测：检出求值 vs 运行世代（一致/已回滚/漂移），附 git 提交
  doctor             只读体检：磁盘/世代/镜像可达/用户守卫/漂移/NixOS 失败单元；
                     写 doctor-*.log，存在 ✗ 时退出码 1
  rollback [N|--list]
                     回滚：standalone 重激活旧世代（缺省=上一个内容不同的世代，
                     y/N 确认、--yes 跳过、--list 只列；更深的回退用显式世代号）；
                     NixOS → sudo nixos-rebuild --rollback / --switch-generation N
  gc [选项]         清理旧世代与无引用路径（--older-than Nd / --all / --system /
                    --dry-run；先用户后系统，NixOS 自动 --system；无需检出目录）
  check [--build] [目标...]
                     验证目标：默认求值（nix eval --raw …drvPath，CI 第一层）；
                     --build 时构建（nix build --no-link，CI 第二层）。
                     目标：nixos wsl x86_64-linux aarch64-linux aarch64-darwin（缺省=当前宿主），
                     可给多个（重复去重）：求值并行、按输入次序汇报、全部跑完才退出
                     （任一失败 rc=1）；--build 串行逐个构建
  update [输入名...|--all]
                     nix flake update 并显示 flake.lock 差异；提交与切换仍手动。
                     缺省时列出 flake 输入供选择：回车（或非交互 EOF）=全部；
                     显式输入名可多个只更新它们；--all 跳过选择直接全量
  flake [-a|--all]  查看 flake.lock 锁定的输入版本（名称/短 rev/日期/ref/来源）；
                    --all 附上游传递输入（版本后缀节点）；纯本地解析，
                    不求值不触网、使用 jq
  module <动作> [名...] [--host K]
                    机器本地模块选配（local.<主机键>.json，gitignored）：
                    init   生成选配文件（以当前有效选择为种子，零行为变化）
                    list   注册表目录 + 该机 on/off（--host 看其它主机键）
                    enable <名...> 启用（未知名/前端不适用/darwin 白名单外拒绝）
                    disable <名...> 停用（未启用为幂等 no-op）
                    主机键：NixOS = 主机名；standalone = 输出名
                    （x86_64-linux / aarch64-linux / aarch64-darwin）
                    改完 roam check <K> 验证、roam switch 生效
  mnt [动作]        管理 mnt 模块的 IHEP Juno SSHFS 挂载：
                     start / stop / status（默认）；无需检出目录
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

# JSON 解析仅用于安装后的 roam；bootstrap 保持安装前的轻量读取。
require_jq() {
  command -v jq >/dev/null 2>&1 || die '需要 jq（由 packages/cli-dev.nix 提供）'
}

meta_username() {
  require_jq
  local u
  u="$(jq -ser 'if length == 1 then .[0] else error("expected one JSON document") end | .username | select(type == "string" and length > 0)' meta.json)" \
    || die '无法从 meta.json 解析 username（须为非空字符串）'
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

# NixOS 分支切换预检：以一次轻求值换取指向约定的干净报错（错配时 nix/nh 的原始
# 属性缺失信息难懂）。求值失败 = 无对应输出；值不等 = 配置内 hostName 与输出名
# 脱节——flake.nix 的 hostnameGuard 断言在 toplevel 求值期也会拦（checkAssertWarn
# throw），预检的价值是更早一步、报错直接给出约定与修法。path:./. 引用 = 含本机
# local.<主机键>.json 选配的视图（本文件全链路约定，见头注释）。
nixos_preflight() {
  local short cfg
  short="$(uname -n)"
  short="${short%%.*}"
  cfg="$(nix eval --raw "path:./.#nixosConfigurations.${short}.config.networking.hostName")" \
    || die "hostname ${short} 无对应 flake 输出 nixosConfigurations.${short}（约定：hosts/ 目录名 = networking.hostName = 输出属性名；新主机经 bootstrap/nixos.sh adopt --target <名> 脚手架，见 README「NixOS 全新安装与迁移」）"
  [ "$cfg" = "$short" ] \
    || die "nixosConfigurations.${short} 内 networking.hostName=${cfg}，与输出属性名不一致（同一约定；改 hosts/${short}/default.nix 或输出名，两侧对齐）"
}

# 当前宿主的 flake 属性路径（check/status/doctor 共用）
host_attr() {
  if is_nixos; then
    printf '%s.config.system.build.toplevel' "$(nixos_output)"
  else
    printf 'homeConfigurations.%s.activationPackage' "$(standalone_target)"
  fi
}

# 状态目录（与 bootstrap 链 tee 日志同源）；switch/rollback/doctor 的日志都落这里
state_dir() { printf '%s/nix-roam' "${XDG_STATE_HOME:-$HOME/.local/state}"; }

new_log() {
  mkdir -p "$(state_dir)"
  printf '%s/%s-%s.log' "$(state_dir)" "$1" "$(date +%Y%m%d-%H%M%S)"
}

# 运行命令并 tee 到状态目录日志，rc 透传（PIPESTATUS[0] 直取命令本身，bash 3.0+）。
run_logged() {
  local prefix log rc
  prefix="$1"
  shift
  log="$(new_log "$prefix")"
  {
    printf 'roam %s\n' "$prefix"
    printf 'date : %s\n' "$(date '+%F %T')"
    printf 'cmd  : %s\n' "$*"
    printf -- '----------------------------------------\n'
  } >"$log"
  set +e
  "$@" 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'roam: 完成，日志 %s\n' "$log"
  else
    printf 'roam: 失败（rc=%s），日志 %s\n' "$rc" "$log" >&2
  fi
  return "$rc"
}

# os-release permits single/double quotes; Darwin has no such file.
os_pretty_name() {
  local label
  label="$(sed -n 's/^PRETTY_NAME=//p' "${1:-/etc/os-release}" 2>/dev/null | head -n 1)" || return 0
  label="${label#\"}"
  label="${label%\"}"
  label="${label#\'}"
  label="${label%\'}"
  printf '%s' "$label"
}

cmd_info() {
  local kind target u current pretty
  pretty="$(os_pretty_name)"
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
    printf 'switch 目标 : nh os switch --diff always path:./. → %s\n' "$(nixos_output)"
    printf 'check 目标  : %s.config.system.build.toplevel\n' "$(nixos_output)"
    if command -v nh >/dev/null 2>&1; then
      printf 'nh          : 可用\n'
    else
      printf 'nh          : 缺失（switch 将拒绝）\n'
    fi
  else
    target="$(standalone_target)"
    printf 'switch 目标 : nh home switch --diff always --configuration %s path:./.\n' "$target"
    printf 'check 目标  : homeConfigurations.%s.activationPackage\n' "$target"
    if command -v nh >/dev/null 2>&1; then
      printf 'nh          : 可用\n'
    else
      printf 'nh          : 缺失（switch 将拒绝；由 packages/cli-dev.nix 提供）\n'
    fi
    if command -v home-manager >/dev/null 2>&1; then
      printf 'home-manager: 可用（status/rollback 世代枚举用）\n'
    else
      printf 'home-manager: 缺失（status/rollback 世代枚举将不可用；由 bootstrap 安装）\n'
    fi
  fi
  printf '检出目录    : %s\n' "$PWD"
}
