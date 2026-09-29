#!/usr/bin/env bash
# .githooks/pre-push 差异门控单测 —— source 钩子加载 gate_needed（钩子主段经
# BASH_SOURCE 执行守卫跳过，与 roam-functions.sh 加载 roam.sh 同款），打桩 git
# 函数后向 gate_needed 管道注入模拟 stdin（pre-push 协议：每行
# <local_ref> <local_sha> <remote_ref> <remote_sha>）。
# 门控的方向性是断言重点（2026-09-29 起黑名单形式）：增量含清单外任一文件——
# *.nix、flake.lock、meta.json、packages/、dotfiles/，及未知路径（含目录导入内
# 非 .nix 文件、新增根文件）—— → rc 0（拦下检查）；增量全为已知非输入
# （docs/tests/bootstrap/.github/.githooks 与根 README/AGENTS/LICENSE/.gitignore）
# → rc 1（放行）；新分支与 sha 缺失 → rc 0（保守跑全量，宁多跑勿漏跑）。
# git 桩：gate 只应调 git diff --name-only <remote> <local>；按场景导出
# GIT_STUB_DIFF（多行差异清单，空串=空差异）与 GIT_STUB_BAD_SHA（命中该 remote
# sha 时模拟本地缺失，rc 128）；桩收到其它 git 调用一律失败点名，防语义漂移。
# 文件尾部另有静态审计：.nix 不得引用 EVAL_SKIP_RE 清单内路径（flake.nix 对
# tests/ 的 checks 引用除外）——黑名单与 Nix 引用交叉时此处先红。
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

# --- 清单外文件 → 拦下（rc 0）：显式输入、未知路径、目录导入内非 .nix 文件 ---
for hit in 'home/common.nix' 'modules/desktop/core.nix' \
  'hosts/nixos/hardware-configuration.nix' 'flake.lock' 'meta.json' \
  'packages/roam.sh' 'packages/roam-completion.bash' \
  'dotfiles/kitty/kitty.conf' \
  'hosts/nixos/notes.txt' 'data.json' 'README.md
flake.nix'; do
  GIT_STUB_DIFF="$hit"
  g "$(line "$L" "$R")"; rc=$?
  expect_rc "gate：清单外文件须拦下（${hit%%$'\n'*}）" 0 "$rc"
done

# --- 未知/近失路径 → 保守拦下（rc 0）：黑名单语义，认不出的就是输入 ---
GIT_STUB_DIFF='mypackages/x
dotfiles-extra/y
notes.flake.lock.bak'
g "$(line "$L" "$R")"; rc=$?
expect_rc 'gate：未知/近失路径须保守拦下' 0 "$rc"

# --- 已知非输入 → 放行（rc 1）：黑名单全集 + fixtures 精度 ---
GIT_STUB_DIFF='docs/roam.md
tests/x.sh
bootstrap/linux.sh
.githooks/pre-push
.github/workflows/eval.yml
README.md
AGENTS.md
LICENSE
.gitignore
tests/fixtures/flake.lock'
g "$(line "$L" "$R")"; rc=$?
expect_rc 'gate：已知非输入增量须放行' 1 "$rc"

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

# --- 静态审计：黑名单与 Nix 引用不得交叉 ---
# 黑名单的反向风险是「Nix 开始引用清单内路径」（readFile ./docs/foo.txt、
# import ./tests/bar.nix 之类）——该文件改动会移动五输出 drvPath 而门控放行。
# grep 级钉住两件事：全仓 .nix 的相对路径字面量指向清单目录的引用仅 flake.nix
# 对 ${./tests} 的一处（checks 专用，不进五输出闭包）；清单目录内不存在 .nix
# 文件（藏不进 import）。
if [ -n "${EVAL_SKIP_RE:-}" ]; then
  ok "EVAL_SKIP_RE 已定义（黑名单非空）"
else
  bad "EVAL_SKIP_RE 未定义/为空（钩子变量改名了？审计与门控脱钩）"
fi
n_ref="$(grep -rnE --include='*.nix' '(\.\./|\./)(\.github|\.githooks|bootstrap|docs|tests)(/|[}"])' "$REPO" | grep -c . || true)"
if [ "$n_ref" = 1 ]; then
  ok ".nix 引用清单目录仅 1 处（flake.nix \${./tests}，checks 专用）"
else
  bad ".nix 引用清单目录 $n_ref 处（期望 1）：黑名单与 Nix 引用交叉——先移文件或改清单，再更新本断言"
fi
n_nix="$(find "$REPO/.github" "$REPO/.githooks" "$REPO/bootstrap" "$REPO/docs" "$REPO/tests" -name '*.nix' 2>/dev/null | grep -c . || true)"
if [ "$n_nix" = 0 ]; then
  ok "清单目录内无 .nix 文件（import 不进五输出闭包）"
else
  bad "清单目录内发现 $n_nix 个 .nix（被 import 即成求值输入而门控放行——移出或改清单）"
fi

printf 'prepush-gate: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
