#!/usr/bin/env bash
# roam 入口：源码直接运行与 Nix 打包使用同一组命令文件。
# Bash 3.2 compatible. JSON commands require the shared CLI package jq.
# path:./. 包含本机 local.*.json；机制与操作说明见 docs/roam.md、docs/modules.md。
set -euo pipefail

roam_lib_dir="${ROAM_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/roam}"
# shellcheck source=/dev/null
source "$roam_lib_dir/core.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/generations.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/switch.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/rollback.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/gc.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/modules.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/check.sh"
# shellcheck source=/dev/null
source "$roam_lib_dir/inputs.sh"

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
    flake) cmd_flake "$@" ;;
    module) cmd_module "$@" ;;
    info) cmd_info "$@" ;;
    help | -h | --help) usage ;;
    *)
      printf 'roam: 未知子命令：%s\n\n' "$cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
fi
