#!/usr/bin/env bash
# tests/ 汇总入口：roam.sh 纯函数单测 + pre-push 差异门控单测 + 补全 harness +
# 脚手架样例块 + 旧名残留检查。
# 检出内直跑（bash tests/run-all.sh）与 flake checks（ROAM_TEST_REPO 指向 store 副本）
# 行为等价；任一失败即非零退出。
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
RC=0
bash "$DIR/roam-functions.sh" || RC=1
bash "$DIR/prepush-gate.sh" || RC=1
bash "$DIR/completion-harness.sh" || RC=1
bash "$DIR/scaffold-blocks.sh" || RC=1
bash "$DIR/repo-references.sh" || RC=1
if [ "$RC" -eq 0 ]; then
  printf 'run-all: ALL PASS\n'
else
  printf 'run-all: FAILURES\n' >&2
fi
exit "$RC"
