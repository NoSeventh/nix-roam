#!/usr/bin/env bash
# roam — nix-roam 统一 CLI 入口
#
# 与 bootstrap/bootstrap.sh 同款宿主探测约定（入口级重复在本仓库是刻意允许的）：
# /etc/NIXOS 存在 → NixOS；否则 standalone Home Manager。
#   roam switch [args...]  NixOS → nh os switch --diff always .（WSL 下失败时打印
#                          stc-exit-4 补救提示）；standalone → nh home switch
#                          --diff always --configuration <系统名输出> .（按求值平台
#                          选输出 + meta.json 用户守卫；nh 自建 activationPackage
#                          再跑 activate —— 世代登记语义与 home-manager switch 相同，
#                          但不显示 HM news、激活日志缺省隐藏，排障时加
#                          --show-activation-logs）。
#                          两条路径全程 tee 到状态目录日志（与 bootstrap 链同惯例）。
#   roam status            漂移检测：检出求值（activationPackage/toplevel 的 outPath）
#                          对比运行世代（standalone 取 (current) 世代、NixOS 取
#                          /run/current-system），回答「该不该再 switch 一次」。
#   roam doctor            只读体检：磁盘余量/世代数量与最老年代/镜像可达性/用户守卫/
#                          漂移/NixOS 失败单元；结果落 doctor-*.log，有 ✗ 时退出码 1。
#   roam rollback [N|--list]
#                          回滚世代：standalone 重激活旧世代（<gen>/activate，y/N
#                          确认，--yes 跳过；缺省取上一个内容不同的世代——rollback
#                          的 activate 会把旧内容登记为新世代号，须跳过同路径重复）；
#                          NixOS → sudo nixos-rebuild --rollback 或 --switch-generation N。
#   roam gc [选项]         手动清理旧世代与无引用 store 路径（自 bootstrap/gc.sh
#                          折入，2026-09-28）：先用户后系统，NixOS 自动启用
#                          --system；--dry-run 只打印命令。机器操作不碰仓库。
#   roam check [--build] [目标...]
#                          CI 两层验证的本地等价物：默认 nix eval --raw 当前宿主目标的
#                          drvPath（第一层）；--build 时 nix build --no-link（第二层）。
#                          目标可显式指定多个：nixos / wsl / x86_64-linux / aarch64-linux /
#                          aarch64-darwin（跨主机核对其它输出，仅求值语义）。多目标求值
#                          并行跑、全部跑完才退出、按输入次序汇报、rc 汇总（不在第一个
#                          失败处中断）——.githooks/pre-push 的 push 前五输出求值门槛即
#                          本命令一条全量调用（该钩子先做差异门控，纯文档增量直接放行）
#   roam update [输入名...|--all]
#                          nix flake update + flake.lock 差异摘要；提交与切换保持手动。
#                          缺省交互选择要更新的输入（回车/EOF=全部），显式输入名或
#                          --all 跳过交互
#   roam info              只读打印宿主探测结论（环境 / 用户守卫 / 将选中的输出）
#
# 需在本仓库检出目录下运行（flake 位置参数 '.' 按 cwd 解析）；rollback 与 gc 例外
# ——rollback 只操作既有 store 世代，gc 是机器操作，均不查仓库。
# 经 packages/roam.nix（writeShellApplication）挂入 packages/cli-dev.nix 四个安装点，
# 也可直接 `bash packages/roam.sh` 调试。保持 macOS Bash 3.2 兼容（无关联数组等
# bash4 特性；只用 bash 内建与 sed/grep 解析——目标机器可能没有 awk，见 gc.sh 同款约束）。
set -euo pipefail

usage() {
  cat <<'EOF'
用法：roam <子命令> [参数]（本仓库统一 CLI；除 rollback 外需在仓库检出目录下运行）

  switch [args...]   按宿主切换：NixOS → nh os switch --diff always .
                     standalone → nh home switch --diff always --configuration <系统输出> .
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

# NixOS 分支切换预检：以一次轻求值换取指向约定的干净报错（错配时 nix/nh 的原始
# 属性缺失信息难懂）。求值失败 = 无对应输出；值不等 = 配置内 hostName 与输出名
# 脱节——flake.nix 的 hostnameGuard 断言在 toplevel 求值期也会拦（checkAssertWarn
# throw），预检的价值是更早一步、报错直接给出约定与修法。
nixos_preflight() {
  local short cfg
  short="$(uname -n)"
  short="${short%%.*}"
  cfg="$(nix eval --raw ".#nixosConfigurations.${short}.config.networking.hostName")" \
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

# --- 2. home-manager 世代解析（standalone 侧 status/rollback 共用）---
# 行样例：`2026-09-28 01:17 : id 21 -> /nix/store/xxx-home-manager-generation (current)`
# 新→旧排列；填平行数组 GEN_DATES/GEN_IDS/GEN_PATHS 与当前下标 GEN_CURRENT；
# 无世代或找不到 (current) 标记时返回 1。
load_hm_generations() {
  GEN_DATES=()
  GEN_IDS=()
  GEN_PATHS=()
  GEN_CURRENT=''
  local line seg date id path i=0
  while read -r line; do
    [ -n "$line" ] || continue
    date="${line%% : id*}"
    seg="${line#* : id }"
    id="${seg%% ->*}"
    path="${seg##* -> }"
    case "$path" in
      *" (current)")
        path="${path% (current)}"
        GEN_CURRENT=$i
        ;;
    esac
    GEN_DATES[i]="$date"
    GEN_IDS[i]="$id"
    GEN_PATHS[i]="$path"
    i=$((i + 1))
  done <<EOF
$(home-manager generations 2>/dev/null)
EOF
  [ -n "$GEN_CURRENT" ] || return 1
}

# NixOS 系统世代号枚举（升序，每行一个；doctor 计数与 rollback --list 共用）。
# 不走 nix-env --list-generations：它需取 profile 锁，非 root 因
# /nix/var/nix/profiles/system.lock 无权限而列空（2026-09-28 wsl 实测）；
# profiles 目录与各 system-N-link 链接全局可读，glob 直读即得。
# 目录可用 ROAM_SYSTEM_PROFILES_DIR 重定向（tests/roam-functions.sh 以临时目录打桩）。
system_generation_ids() {
  local l n dir
  dir="${ROAM_SYSTEM_PROFILES_DIR:-/nix/var/nix/profiles}"
  for l in "$dir"/system-*-link; do
    n="${l##*/system-}"
    n="${n%-link}"
    case "$n" in
      '' | *[!0-9]*) continue ;;
    esac
    printf '%s\n' "$n"
  done | sort -n
}

# 漂移检测核心（status 展示、doctor 复用）：检出求值 outPath vs 运行世代。
# 填 DRIFT_EXPECTED / DRIFT_CURRENT / DRIFT_VERDICT，standalone 另附 DRIFT_DETAIL。
compute_drift() {
  DRIFT_EXPECTED=''
  DRIFT_CURRENT=''
  DRIFT_VERDICT=''
  DRIFT_DETAIL=''
  if is_nixos; then
    DRIFT_EXPECTED="$(nix eval --raw ".#$(host_attr).outPath")" || return 1
    DRIFT_CURRENT="$(readlink /run/current-system)" || return 1
    if [ "$DRIFT_EXPECTED" = "$DRIFT_CURRENT" ]; then
      DRIFT_VERDICT='一致（运行环境 = 检出）'
    else
      DRIFT_VERDICT='漂移（检出有未激活的变化；roam switch 生效）'
    fi
  else
    local j seen_hist=false
    load_hm_generations || return 1
    DRIFT_EXPECTED="$(nix eval --raw ".#$(host_attr).outPath")" || return 1
    DRIFT_CURRENT="${GEN_PATHS[$GEN_CURRENT]}"
    DRIFT_DETAIL="世代 id ${GEN_IDS[$GEN_CURRENT]}（${GEN_DATES[$GEN_CURRENT]}）"
    # 注意：rollback 的 activate 会把旧内容登记为新世代号，因此「检出是否激活过」
    # 要看它是否等于任一世代路径，而不是只比最新一条。
    j=0
    while [ "$j" -lt "${#GEN_PATHS[@]}" ]; do
      if [ "${GEN_PATHS[$j]}" = "$DRIFT_EXPECTED" ]; then
        seen_hist=true
        break
      fi
      j=$((j + 1))
    done
    if [ "$DRIFT_EXPECTED" = "$DRIFT_CURRENT" ]; then
      DRIFT_VERDICT='一致（运行环境 = 检出）'
    elif [ "$seen_hist" = true ]; then
      DRIFT_VERDICT="已回滚或检出已回退（检出对应历史世代 id ${GEN_IDS[$j]}；roam switch 可前进回检出）"
    else
      DRIFT_VERDICT='漂移（检出有未激活的变化；roam switch 生效）'
    fi
  fi
}

# --- 3. 子命令 ---
cmd_switch() {
  local rc target u
  repo_check
  if is_nixos; then
    command -v nh >/dev/null 2>&1 \
      || die "未找到 nh（NixOS 侧经 packages/cli-dev.nix 共享列表落系统位；首次进入闭包前可先 sudo nixos-rebuild switch --flake .#<主机名> 自举一次）"
    nixos_preflight
    if run_logged switch nh os switch --diff always . "$@"; then
      return 0
    else
      rc=$?
      if is_wsl; then
        printf 'roam: nh 退出码 %s。NixOS-WSL 下 stc exit 4 时世代可能未落盘：\n' "$rc" >&2
        printf '  Windows 侧 wsl --shutdown 后重试；或 sudo nixos-rebuild switch --flake .#wsl 补落世代（见 AGENTS.md）\n' >&2
      fi
      return "$rc"
    fi
  fi
  u="$(meta_username)"
  [ "$(id -un)" = "$u" ] \
    || die "当前用户是 $(id -un)，不是 $u；拒绝切换（本地用户名在 meta.json 单点定义）"
  target="$(standalone_target)"
  command -v nh >/dev/null 2>&1 \
    || die "未找到 nh（standalone 侧由 packages/cli-dev.nix 提供；首次进入闭包前可先 home-manager switch --flake .#${target} 自举一次）"
  # nh 4.4.2 把裸 .#attr 解析成 packages.<system>.<attr> 简写而非 homeConfigurations
  # 属性，须用 --configuration 显式点名 + 位置参数 . 传 flake（nh 上游 master 已改，
  # 以锁定 nixpkgs 的实际行为为准）。
  if run_logged switch nh home switch --diff always --configuration "$target" . "$@"; then
    return 0
  else
    rc=$?
    return "$rc"
  fi
}

cmd_status() {
  local git_line dirty_n
  repo_check
  compute_drift || die '漂移计算失败（求值或世代读取不成功）'
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_line="$(git log -1 --format='%h %s' 2>/dev/null || printf '(无提交)')"
    dirty_n="$(git status --porcelain 2>/dev/null | grep -c . || true)"
    if [ "${dirty_n:-0}" -gt 0 ]; then
      git_line="${git_line}（${dirty_n} 个未提交变更）"
    else
      git_line="${git_line}（工作树干净）"
    fi
  else
    git_line='(非 git 检出)'
  fi
  printf '运行世代  : %s%s\n' "${DRIFT_CURRENT##*/}" "${DRIFT_DETAIL:+  ${DRIFT_DETAIL}}"
  printf '检出求值  : %s\n' "${DRIFT_EXPECTED##*/}"
  printf 'Git       : %s\n' "$git_line"
  printf '状态      : %s\n' "$DRIFT_VERDICT"
}

cmd_doctor() {
  local log fails=0 warns=0 u parts avail_k avail_g subs s code gens oldest failed_n
  repo_check
  log="$(new_log doctor)"
  : >"$log"
  out() {
    printf '%s\n' "$*"
    printf '%s\n' "$*" >>"$log"
  }
  ok() {
    out "  ✓ $*"
  }
  warn() {
    out "  ! $*"
    warns=$((warns + 1))
  }
  fail() {
    out "  ✗ $*"
    fails=$((fails + 1))
  }
  out "roam doctor — $(date '+%F %T')（$(is_nixos && printf NixOS || printf standalone)，$(uname -srm)）"

  # 1. 用户守卫
  u="$(meta_username)"
  if [ "$(id -un)" = "$u" ]; then
    ok "用户守卫：$(id -un) = meta.json ${u}"
  else
    fail "用户守卫：当前 $(id -un) ≠ meta.json ${u}（switch 将拒绝）"
  fi

  # 2. /nix 磁盘余量（满盘是 Nix 最经典故障）
  parts=()
  read -r -a parts <<<"$(df -Pk /nix 2>/dev/null | tail -1)"
  if [ "${#parts[@]}" -ge 5 ]; then
    avail_k="${parts[3]}"
    avail_g=$((avail_k / 1024 / 1024))
    if [ "$avail_g" -lt 5 ]; then
      fail "/nix 余量仅 ${avail_g}G（<5G，构建/切换可能失败；roam gc 清理）"
    elif [ "$avail_g" -lt 20 ]; then
      warn "/nix 余量 ${avail_g}G（<20G，建议 roam gc）"
    else
      ok "/nix 余量 ${avail_g}G"
    fi
  else
    warn "无法读取 df /nix，跳过磁盘检查"
  fi

  # 3. 世代健康（数量与最老年代，不做日期运算——macOS BSD date 无 -d）
  if is_nixos; then
    gens="$(system_generation_ids | grep -c . || true)"
    if [ -n "$gens" ] && [ "$gens" -gt 0 ]; then
      if [ "$gens" -gt 30 ]; then
        warn "系统世代 ${gens} 个（>30，建议 roam gc）"
      else
        ok "系统世代 ${gens} 个"
      fi
    else
      warn "无法列出系统世代，跳过"
    fi
  else
    if load_hm_generations; then
      gens="${#GEN_PATHS[@]}"
      oldest="${GEN_DATES[$((gens - 1))]}"
      if [ "$gens" -gt 30 ]; then
        warn "home-manager 世代 ${gens} 个（>30，建议 roam gc），最老 ${oldest%% *}"
      else
        ok "home-manager 世代 ${gens} 个，最老 ${oldest%% *}"
      fi
    else
      fail "无法解析 home-manager 世代"
    fi
  fi

  # 4. 镜像可达性（meta.json 单点定义的 substituters；任何 HTTP 码=服务器应答）
  subs="$(sed -n 's/.*"substituters"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' meta.json)"
  if command -v curl >/dev/null 2>&1 && [ -n "$subs" ]; then
    # shellcheck disable=SC2086
    for s in $subs; do
      code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$s" 2>/dev/null || true)"
      if [ "$code" = 000 ] || [ -z "$code" ]; then
        fail "镜像不可达：${s}"
      else
        ok "镜像可达：${s}（HTTP ${code}）"
      fi
    done
  else
    warn "无 curl 或未配置 substituters，跳过镜像检查"
  fi

  # 5. 漂移
  if compute_drift; then
    case "$DRIFT_VERDICT" in
      一致*) ok "${DRIFT_VERDICT}" ;;
      *) warn "${DRIFT_VERDICT}" ;;
    esac
  else
    fail "漂移计算失败（求值或世代读取不成功）"
  fi

  # 6. NixOS 失败单元
  if is_nixos && command -v systemctl >/dev/null 2>&1; then
    failed_n="$(systemctl --failed --no-legend 2>/dev/null | grep -c . || true)"
    if [ "${failed_n:-0}" -eq 0 ]; then
      ok "systemd 失败单元：0"
    else
      fail "systemd 失败单元 ${failed_n} 个（systemctl --failed 查看）"
    fi
  fi

  out "----------------------------------------"
  out "结果：$((fails)) 项失败 / ${warns} 项提醒；日志 ${log}"
  [ "$fails" -eq 0 ]
}

cmd_rollback() {
  local want='' list=false yes=false i target_idx total seg_cur seg_tgt log rc answer n d cur_link
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --list) list=true ;;
      -y | --yes) yes=true ;;
      -*) die "rollback: 未知选项：$1" ;;
      *[!0-9]*) die "rollback: 世代号必须是数字：$1（roam rollback --list 查看）" ;;
      *) want="$1" ;;
    esac
    shift
  done
  if is_nixos; then
    if [ "$list" = true ]; then
      # 非 root 也能列（nix-env 需 profile 锁，见 system_generation_ids 注释）；
      # 日期取链接自身 mtime（GNU stat 不跟随符号链接，与 nix-env 同源），
      # 当前世代以 system 链接目标为准。
      cur_link="$(readlink /nix/var/nix/profiles/system 2>/dev/null)"
      system_generation_ids | while read -r n; do
        d="$(stat -c '%y' "/nix/var/nix/profiles/system-${n}-link" 2>/dev/null)"
        d="${d%%.*}"
        if [ "system-${n}-link" = "${cur_link##*/}" ]; then
          printf 'id %-4s %s  （当前）\n' "$n" "$d"
        else
          printf 'id %-4s %s\n' "$n" "$d"
        fi
      done
      return 0
    fi
    printf 'roam: NixOS 回滚走 nixos-rebuild（nh 无回滚入口；sudo 自行提权）\n'
    if [ -n "$want" ]; then
      run_logged rollback sudo nixos-rebuild switch --switch-generation "$want"
      return $?
    fi
    run_logged rollback sudo nixos-rebuild switch --rollback
    return $?
  fi
  load_hm_generations || die '未找到 home-manager 世代（本机尚未激活过？）'
  total="${#GEN_PATHS[@]}"
  if [ "$list" = true ]; then
    i=0
    while [ "$i" -lt "$total" ]; do
      seg_cur=''
      if [ "$i" = "$GEN_CURRENT" ]; then
        seg_cur='（当前）'
      fi
      printf 'id %-4s %s  %-8s %s\n' "${GEN_IDS[$i]}" "${GEN_DATES[$i]}" "$seg_cur" "${GEN_PATHS[$i]##*/}"
      i=$((i + 1))
    done
    return 0
  fi
  target_idx=''
  if [ -n "$want" ]; then
    i=0
    while [ "$i" -lt "$total" ]; do
      if [ "${GEN_IDS[$i]}" = "$want" ]; then
        target_idx=$i
        break
      fi
      i=$((i + 1))
    done
    [ -n "$target_idx" ] || die "没有世代 id ${want}（roam rollback --list 查看）"
    if [ "$target_idx" = "$GEN_CURRENT" ]; then
      die "id ${want} 已是当前世代"
    fi
  else
    # 缺省回滚目标 = 当前世代之后第一个「内容不同」的世代：rollback 的 activate 会把
    # 旧内容登记为新世代号，直接取下一条会踩回刚离开的内容（同 store 路径）。
    target_idx=$((GEN_CURRENT + 1))
    while [ "$target_idx" -lt "$total" ] && [ "${GEN_PATHS[$target_idx]}" = "${GEN_PATHS[$GEN_CURRENT]}" ]; do
      target_idx=$((target_idx + 1))
    done
    [ "$target_idx" -lt "$total" ] || die '当前已是最早世代，没有更早的可回滚'
  fi
  seg_cur="${GEN_PATHS[$GEN_CURRENT]##*/}（id ${GEN_IDS[$GEN_CURRENT]}）"
  seg_tgt="${GEN_PATHS[$target_idx]##*/}（id ${GEN_IDS[$target_idx]}，${GEN_DATES[$target_idx]}）"
  printf '回滚：%s\n  → %s\n' "$seg_cur" "$seg_tgt"
  if [ "$yes" = false ]; then
    printf '确认回滚？[y/N] '
    read -r answer || answer=''
    case "$answer" in
      y | Y | yes | YES) : ;;
      *)
        printf 'roam: 已取消\n'
        return 0
        ;;
    esac
  fi
  log="$(new_log rollback)"
  {
    printf 'roam rollback\n'
    printf 'date : %s\n' "$(date '+%F %T')"
    printf 'from : %s\n' "$seg_cur"
    printf 'to   : %s\n' "$seg_tgt"
    printf -- '----------------------------------------\n'
  } >"$log"
  set +e
  "${GEN_PATHS[$target_idx]}/activate" 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'roam: 已回滚到 id %s（roam status 查看；roam switch 回到检出）\n' "${GEN_IDS[$target_idx]}"
  else
    printf 'roam: 回滚失败（rc=%s），日志 %s\n' "$rc" "$log" >&2
  fi
  return "$rc"
}

# --- gc：手动清理旧世代与无引用 store 路径 ---
# 2026-09-28 自 bootstrap/gc.sh 折入（该脚本随迁移删除）：gc 是机器操作不碰仓库，
# 不应因脚本住在检出里而要求检出目录；折入同时消掉它与本文件重复的宿主探测。
# 语义与原脚本一致：先用户后系统（sudo 自行调用）、NixOS 自动启用 --system、
# --dry-run 只打印命令、不更新引导菜单、不修改自动清理配置。
gc_usage() {
  cat <<'EOF'
用法：roam gc [选项]

  --older-than Nd  清理超过 N 天的旧世代，默认 14d（N 必须为正整数）
  --all            清理全部非当前世代
  --system         在用户清理之后，也以 root 清理系统/root 的旧世代
  --dry-run        仅打印将运行的命令，不删除世代、不执行垃圾回收
  -h, --help       显示本帮助

请以普通用户运行，gc 在需要时自行调用 sudo。
NixOS 自动启用 --system；普通 Linux / WSL / macOS 默认清理用户环境。
macOS 使用 nix-darwin 时，可加 --system 清理其系统旧世代。
删除的世代将无法直接回滚；仍被当前环境或其他 GC 根引用的包会保留。
不更新 NixOS / nix-darwin 的引导菜单，也不修改自动清理配置。
EOF
}

cmd_gc() {
  local period=14d policy=age policy_set=false system_gc=false dry_run=false
  local os_name environment gc_bin
  local gc_args
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --older-than)
        [ "$#" -ge 2 ] || die 'gc: --older-than 需要参数，例如 30d'
        [ "$policy_set" = false ] || die 'gc: --older-than 与 --all 只能指定一次且不能混用'
        [[ "$2" =~ ^[1-9][0-9]*d$ ]] || die 'gc: 保留期限必须是正整数天，例如 14d'
        period="$2"
        policy_set=true
        shift 2
        ;;
      --all)
        [ "$policy_set" = false ] || die 'gc: --older-than 与 --all 只能指定一次且不能混用'
        policy=all
        policy_set=true
        shift
        ;;
      --system) system_gc=true; shift ;;
      --dry-run) dry_run=true; shift ;;
      -h | --help) gc_usage; return 0 ;;
      *) gc_usage >&2; die "gc: 未知参数：$1" ;;
    esac
  done

  # 宿主环境标签与探测沿用本文件既有约定（is_nixos / is_wsl）
  case "$kernel" in
    Linux)
      os_name=Linux
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091  # 目标机运行时文件，静态检查无法跟随
        os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-Linux}")"
      fi
      if is_nixos; then
        environment=NixOS
        system_gc=true
      elif is_wsl; then
        environment="$os_name / WSL（独立 Nix）"
      else
        environment="$os_name（独立 Nix）"
      fi
      ;;
    Darwin) environment='macOS / Darwin' ;;
    *) die "gc: 不支持的系统：$kernel" ;;
  esac
  printf '当前环境：%s\n' "$environment"

  if [ "${SUDO_USER:-root}" != root ] && [ "$EUID" -eq 0 ]; then
    die 'gc: 请去掉外层 sudo，以便先清理你自己的 Home Manager 世代；需要时 gc 会调用 sudo'
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
  [ -n "$gc_bin" ] || die 'gc: 未找到 nix-collect-garbage，请先安装 Nix 或加载 Nix 环境'
  if [ "$system_gc" = true ] && [ "$EUID" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die 'gc: 系统清理需要 sudo'
  fi

  # 先用户、后系统；预览模式不调用任何清理命令
  gc_args=(--delete-older-than "$period")
  if [ "$policy" = all ]; then
    gc_args=(--delete-old)
  fi
  gc_run() {
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
  gc_run "$gc_bin" "${gc_args[@]}"
  if [ "$system_gc" = true ] && [ "$EUID" -ne 0 ]; then
    gc_run sudo -H -- "$gc_bin" "${gc_args[@]}"
  fi
}

# 目标名 → flake 属性路径（check 显式目标专用；host_attr 是「当前宿主」的同一
# 映射。未知目标即 die——cmd_check 解析期借它做即时校验）
check_attr() {
  case "$1" in
    nixos | wsl) printf 'nixosConfigurations.%s.config.system.build.toplevel' "$1" ;;
    x86_64-linux | aarch64-linux | aarch64-darwin)
      printf 'homeConfigurations.%s.activationPackage' "$1"
      ;;
    *) die "未知目标：$1（可用：nixos wsl x86_64-linux aarch64-linux aarch64-darwin，缺省=当前宿主）" ;;
  esac
}

cmd_check() {
  local build=false targets='' attrs='' t a rc=0 total=0 i cktmp
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --build) build=true ;;
      -*) die "check: 未知选项：$1" ;;
      *)
        # 目标名解析期即校验（未知名 die）；重复目标静默去重（保首现次序）
        check_attr "$1" >/dev/null
        case " $targets " in
          *" $1 "*) : ;;
          *) targets="$targets $1" ;;
        esac
        ;;
    esac
    shift
  done
  repo_check
  if [ -z "$targets" ]; then
    attrs="$(host_attr)" # 缺省：当前宿主单目标（与旧版语义一致）
  else
    # 目标名均为经校验的标识符（无空格/通配），展开安全
    # shellcheck disable=SC2086
    for t in $targets; do
      attrs="$attrs $(check_attr "$t")"
    done
    attrs="${attrs# }"
  fi
  # 全部目标跑完再退出：一次 push 前核对应看到全部失败，而非停在第一个；汇报
  # 按输入次序（并行完成次序不定，汇报次序必须稳定可测）。求值并行——各输出
  # 相互独立且只读，墙钟≈最慢单个而非总和（实测收益见 VALIDATION.md 当日记录）；
  # --build 保持串行——并发 nix build 各自按 max-jobs 展开构建进程，内存/CPU 会
  # 成倍叠加，只读求值没有这个问题。
  if [ "$build" = true ]; then
    # shellcheck disable=SC2086
    for a in $attrs; do
      total=$((total + 1))
      printf 'roam check: 构建 .#%s\n' "$a"
      nix build --no-link ".#${a}" || rc=1
    done
  else
    # 目标名均为经校验的标识符（无空格/通配），展开安全
    # shellcheck disable=SC2086
    set -- $attrs
    total=$#
    if [ "$total" -gt 1 ]; then
      printf 'roam check: 并行求值 %s 个目标\n' "$total"
    fi
    cktmp="$(mktemp -d)"
    i=0
    for a in "$@"; do
      i=$((i + 1))
      (
        # 子壳双分支显式写 rc：nix 失败时若不接住，set -e 会在写 rc 前中止子壳
        if nix eval --raw ".#${a}.drvPath" >"$cktmp/$i.out" 2>"$cktmp/$i.err"; then
          printf '0\n' >"$cktmp/$i.rc"
        else
          printf '%s\n' "$?" >"$cktmp/$i.rc"
        fi
      ) &
    done
    wait
    i=0
    for a in "$@"; do
      i=$((i + 1))
      printf 'roam check: 求值 .#%s\n' "$a"
      cat "$cktmp/$i.out"
      if [ -s "$cktmp/$i.out" ]; then printf '\n'; fi
      cat "$cktmp/$i.err" >&2
      if [ "$(cat "$cktmp/$i.rc")" -ne 0 ]; then rc=1; fi
    done
    rm -rf "$cktmp"
  fi
  if [ "$total" -gt 1 ]; then
    if [ "$rc" -eq 0 ]; then
      printf 'roam check: %s 个目标全部通过\n' "$total"
    else
      printf 'roam check: 存在失败目标（见上），共 %s 个\n' "$total" >&2
    fi
  fi
  return "$rc"
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
    printf 'switch 目标 : nh home switch --diff always --configuration %s .\n' "$target"
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

# --- 4. 分发 ---
# 执行守卫：被 source 时不分发（tests/roam-functions.sh 加载纯函数做单测）；
# 直接执行（bin/roam、bash packages/roam.sh）时 $0 与 BASH_SOURCE 一致，照常分发。
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="${1:-help}"
  if [ "$#" -gt 0 ]; then
    shift
  fi
  case "$cmd" in
    switch) cmd_switch "$@" ;;
    status) cmd_status "$@" ;;
    doctor) cmd_doctor "$@" ;;
    rollback) cmd_rollback "$@" ;;
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
fi
