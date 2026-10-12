#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034
# --- 3. 子命令 ---
cmd_switch() {
  local rc target u short
  repo_check
  if is_nixos; then
    command -v nh >/dev/null 2>&1 \
      || die "未找到 nh（NixOS 侧经 packages/cli-dev.nix 共享列表落系统位；首次进入闭包前可先 sudo nixos-rebuild switch --flake .#<主机名> 自举一次）"
    nixos_preflight
    short="$(uname -n)"
    short="${short%%.*}"
    # path:./. 引用让本机 local.<主机键>.json 选配进求值；-H 显式点名输出——
    # path: 引用下 nh 按引用串推断主机的默认行为不再可靠（目录名约定不再适用）。
    if run_logged switch nh os switch --diff always -H "$short" path:./. "$@"; then
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
  # 属性，须用 --configuration 显式点名 + 位置参数传 flake（nh 上游 master 已改，
  # 以锁定 nixpkgs 的实际行为为准）。path:./. 引用 = 含本机 local 选配的视图。
  if run_logged switch nh home switch --diff always --configuration "$target" path:./. "$@"; then
    return 0
  else
    rc=$?
    return "$rc"
  fi
}

cmd_status() {
  local git_line dirty_n mkey mfile mn
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
  # 模块选配一行速览（选配机制存在与否不影响 status 本体；探测失败静默省略）
  mkey="$(module_current_key 2>/dev/null || true)"
  if [ -n "$mkey" ]; then
    mfile="$(local_file "$mkey")"
    if [ -f "$mfile" ]; then
      mn="$(local_selection_read "$mkey" | grep -c . || true)"
      printf '模块选配  : %s（%s 层启用）\n' "${mfile#./}" "${mn:-0}"
    else
      printf '模块选配  : 无 local.%s.json（入库默认集）\n' "$mkey"
    fi
  fi
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
  require_jq
  subs="$(jq -ser 'if length == 1 then .[0] else error("expected one JSON document") end | .substituters | select(type == "string" and length > 0)' meta.json)" || die 'meta.json 缺有效 substituters'
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
