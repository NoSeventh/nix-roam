#!/usr/bin/env bash
# .githooks/pre-push 差异门控单测 —— source 钩子加载 gate_needed（钩子主段经
# BASH_SOURCE 执行守卫跳过，与 roam-functions.sh 加载 roam.sh 同款），打桩 git
# 函数后向 gate_needed 管道注入模拟 stdin（pre-push 协议：每行
# <local_ref> <local_sha> <remote_ref> <remote_sha>）。
# 门控的方向性是断言重点：命中任一求值输入 → rc 0（拦下检查）；纯文档增量 /
# 删除推送 → rc 1（放行）；新分支与 sha 缺失 → rc 0（保守跑全量，宁多跑勿漏跑）。
# git 桩：gate 只应调 git diff --name-only <remote> <local>；按场景导出
# GIT_STUB_DIFF（多行差异清单，空串=空差异）与 GIT_STUB_BAD_SHA（命中该 remote
# sha 时模拟本地缺失，rc 128）；桩收到其它 git 调用一律失败点名，防语义漂移。
# 运行：检出内 bash tests/prepush-gate.sh；或经 flake checks（ROAM_TEST_REPO）。
set -u

REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1" >&2; }
expect_rc() { # 描述 期望rc 实际rc
  if [ "$3" = "$2" ]; then ok "$1"; else bad "$1：rc=$3 want $2"; fi
}

# 加载钩子的 gate_needed；钩子的 set -euo pipefail 会带上（-u/pipefail 保留，
# errexit 关掉——断言逐条显式判 rc），与 roam-functions.sh 同款处理
# shellcheck source=/dev/null
. "$REPO/.githooks/pre-push"
set +e

GIT_STUB_DIFF=''
GIT_STUB_BAD_SHA=''
git() {
  case "$1 $2" in
    'diff --name-only')
      if [ -n "$GIT_STUB_BAD_SHA" ] && [ "$3" = "$GIT_STUB_BAD_SHA" ]; then
        printf 'fatal: bad object (stub)\n' >&2
        return 128
      fi
      [ -n "$GIT_STUB_DIFF" ] && printf '%s\n' "$GIT_STUB_DIFF"
      return 0
      ;;
  esac
  printf 'prepush-gate: 意外的 git 调用：%s\n' "$*" >&2
  return 1
}

# 模拟 ref 行（sha 只需满足「非全零」语义，短伪 sha 即可）
L='local123' R='remote456' L2='local789' R2='remote012'
Z='0000000000000000000000000000000000000000'
line() { printf 'refs/heads/master %s refs/heads/master %s' "$1" "$2"; }
g() { printf '%s\n' "$1" | gate_needed; }

# --- 命中求值输入 → 拦下（rc 0）---
for hit in 'home/common.nix' 'modules/desktop/core.nix' \
  'hosts/nixos/hardware-configuration.nix' 'flake.lock' 'meta.json' \
  'packages/roam.sh' 'packages/roam-completion.bash' \
  'dotfiles/kitty/kitty.conf' 'README.md
flake.nix'; do
  GIT_STUB_DIFF="$hit"
  g "$(line "$L" "$R")"; rc=$?
  expect_rc "gate：命中求值输入须拦下（${hit%%$'\n'*}）" 0 "$rc"
done

# --- 近失名与纯文档/脚本增量 → 放行（rc 1）---
GIT_STUB_DIFF='mypackages/x
dotfiles-extra/y
docs/dotfiles.md
notes.flake.lock.bak
docs/roam.md
tests/x.sh
bootstrap/linux.sh
.githooks/pre-push'
g "$(line "$L" "$R")"; rc=$?
expect_rc 'gate：近失名/纯文档脚本增量须放行' 1 "$rc"

# --- 删除推送（local 全零）：无新提交，放行且不消费 diff ---
GIT_STUB_DIFF='home/common.nix' # 桩即使配了命中差异也不应被读到
g "$(line "$Z" "$R")"; rc=$?
expect_rc 'gate：删除推送（local 全零）放行' 1 "$rc"

# --- 新分支（remote 全零）：无基线可比，保守拦下 ---
GIT_STUB_DIFF=''
g "$(line "$L" "$Z")"; rc=$?
expect_rc 'gate：新分支（remote 全零）保守跑全量' 0 "$rc"

# --- diff 失败（remote sha 本地缺失）：保守拦下 ---
GIT_STUB_BAD_SHA="$R"
g "$(line "$L" "$R")"; rc=$?
expect_rc 'gate：diff 失败（sha 缺失）保守跑全量' 0 "$rc"
GIT_STUB_BAD_SHA=''

# --- 空差异（重推同一提交）：放行 ---
GIT_STUB_DIFF=''
g "$(line "$L" "$L")"; rc=$?
expect_rc 'gate：空差异（重推同提交）放行' 1 "$rc"

# --- 多 ref：任一命中即拦 / 全纯文档放行 / 删除+文档混合放行 ---
GIT_STUB_DIFF='home/common.nix'
printf '%s\n%s\n' "$(line "$L2" "$R2")" "$(line "$L" "$R")" | gate_needed; rc=$?
expect_rc 'gate：多 ref 任一命中即拦' 0 "$rc"
GIT_STUB_DIFF='docs/a.md'
printf '%s\n%s\n' "$(line "$L2" "$R2")" "$(line "$L" "$R")" | gate_needed; rc=$?
expect_rc 'gate：多 ref 全纯文档放行' 1 "$rc"
printf '%s\n%s\n' "$(line "$Z" "$R2")" "$(line "$L" "$R")" | gate_needed; rc=$?
expect_rc 'gate：删除+纯文档混合放行' 1 "$rc"

printf '\n' | gate_needed; rc=$?
expect_rc 'gate：空 stdin（无可推送增量）放行' 1 "$rc"

printf 'prepush-gate: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
