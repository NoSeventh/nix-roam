#!/usr/bin/env bash
# roam 补全 harness —— 模拟 COMP_WORDS/COMP_CWORD 直调 _roam（与实机 TAB 同一代码路径）。
# 断言只取宿主无关子集：rollback 的世代号依赖实机 profile 状态（本机/CI 沙箱各异），
# 只断言旗标存在性；update 的输入名读当前检出 flake.lock（真实数据），只做成员断言。
# 运行：检出内 bash tests/completion-harness.sh；或经 flake checks（ROAM_TEST_REPO）。
set -u

REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1" >&2; }
expect_eq() { # 描述 got want
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1：got [$2] want [$3]"; fi
}
expect_contains() { # 描述 haystack needle
  case " $2 " in
    *" $3 "*) ok "$1" ;;
    *) bad "$1：[$2] 不含 [$3]" ;;
  esac
}

# shellcheck source=/dev/null
. "$REPO/packages/roam-completion.bash"

# 以参数构造 COMP_WORDS（末位=当前词），返回补全项（每行一个）
compline() {
  COMP_WORDS=("$@")
  COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
  COMPREPLY=()
  _roam
  if [ "${#COMPREPLY[@]}" -gt 0 ]; then
    printf '%s\n' "${COMPREPLY[@]}"
  fi
}

# 便于整表比较：多行输出并成单行（空格分隔）
joined() { local s; s="$(tr '\n' ' ')"; printf '%s' "${s% }"; }

# update 分支读 cwd 的 flake.lock —— 在仓库根跑（store 副本与检出同样可读）
cd "$REPO" || exit 9

# --- 一级 ---
got="$(compline roam '' | joined)"
expect_eq '一级：八子命令 + help' "$got" 'switch status doctor rollback gc check update info help -h --help'
got="$(compline roam ch | joined)"
expect_eq '前缀 ch → check' "$got" 'check'
got="$(compline roam - | joined)"
expect_eq '前缀 - → 帮助旗标' "$got" '-h --help'

# --- check：旗标 + 五目标 + 旗标后补目标 ---
got="$(compline roam check '' | joined)"
expect_eq 'check：旗标 + 五目标' "$got" '--build nixos wsl x86_64-linux aarch64-linux aarch64-darwin'
got="$(compline roam check --b | joined)"
expect_eq 'check：--b → --build' "$got" '--build'
got="$(compline roam check ws | joined)"
expect_eq 'check：ws → wsl' "$got" 'wsl'
got="$(compline roam check a | joined)"
expect_eq 'check：a → 双 aarch64 目标' "$got" 'aarch64-linux aarch64-darwin'
got="$(compline roam check --build '' | joined)"
expect_eq 'check：旗标后仍补目标' "$got" '--build nixos wsl x86_64-linux aarch64-linux aarch64-darwin'

# --- update：旗标 + 实时输入名（flake.lock 真实数据，成员断言）---
got="$(compline roam update '' | joined)"
case "$got" in
  '-a --all' | '-a --all '*) ok 'update：旗标前缀' ;;
  *) bad "update：旗标前缀 got [$got]" ;;
esac
expect_contains 'update：补出 nixpkgs 输入名' "$got" nixpkgs
expect_contains 'update：补出 nixvim 输入名' "$got" nixvim

# --- rollback：世代号宿主相关，只断言旗标 ---
got="$(compline roam rollback '' | joined)"
expect_contains 'rollback：--list' "$got" --list
expect_contains 'rollback：-y' "$got" -y
expect_contains 'rollback：--yes' "$got" --yes

# --- gc：四旗标与 --older-than 取值 ---
got="$(compline roam gc '' | joined)"
expect_eq 'gc：四旗标' "$got" '--dry-run --all --system --older-than'
got="$(compline roam gc --older-than '' | joined)"
expect_eq 'gc：--older-than 取值' "$got" '7d 14d 30d'

# --- 无自有补全 / 未知子命令 ---
got="$(compline roam switch '')"
expect_eq 'switch：空补全' "$got" ''
got="$(compline roam status '')"
expect_eq 'status：空补全' "$got" ''
got="$(compline roam bogus '')"
expect_eq '未知子命令：空补全' "$got" ''

printf 'completion-harness: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
