#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034
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
    DRIFT_EXPECTED="$(nix eval --raw "path:./.#$(host_attr).outPath")" || return 1
    DRIFT_CURRENT="$(readlink /run/current-system)" || return 1
    if [ "$DRIFT_EXPECTED" = "$DRIFT_CURRENT" ]; then
      DRIFT_VERDICT='一致（运行环境 = 检出）'
    else
      DRIFT_VERDICT='漂移（检出有未激活的变化；roam switch 生效）'
    fi
  else
    local j seen_hist=false
    load_hm_generations || return 1
    DRIFT_EXPECTED="$(nix eval --raw "path:./.#$(host_attr).outPath")" || return 1
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
