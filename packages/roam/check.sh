#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034
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
      printf 'roam check: 构建 path:./.#%s\n' "$a"
      nix build --no-link "path:./.#${a}" || rc=1
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
        if nix eval --raw "path:./.#${a}.drvPath" >"$cktmp/$i.out" 2>"$cktmp/$i.err"; then
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
      printf 'roam check: 求值 path:./.#%s\n' "$a"
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
