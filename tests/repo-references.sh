#!/usr/bin/env bash
# 旧仓名残留检查：Gitee 仓库已更名 nix-roam（旧名经 Gitee 改名重定向 old→new
# 仍可达，2026-09-29 实测 302；但重定向在旧名被他人注册后会死——届时任何仍指向
# 旧名的可取用 URL（curl|bash 一键安装、git clone、archive 回退、sync workflow
# 拉源）会取到陌生人的内容，属供应链风险而非单纯断链）。
#
# 断言：仓库跟踪文件中不得出现旧名的「可取用 URL」形式
# （gitee.com/qihaoxu/<旧名>，即 raw / .git / archive / 仓库页四种取用前缀共有的
# 域名+路径段）。裸旧名允许两类合法存留，本测试放行：
#   1) bootstrap 脚本「既有检出识别」的 alternation grep -qE 'nixos-niri-noctalia|nix-roam'
#      ——识别旧名时代克隆的 remote.origin.url（无 URL 前缀，是匹配模式非取用目标，
#      删掉会使旧检出被当作异物重克隆）；下方另有计数断言钉死这 4 处不被误清理。
#   2) docs/VALIDATION.md 的历史记录（如实记载需要；日期记录不是取用入口）。
# 本文件自身含模式串（作为检查针），亦在排除之列。
set -u

REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1" >&2; }
expect_count() { # 描述 文本 子串 期望次数
  local n
  n="$(printf '%s\n' "$2" | grep -cF -- "$3" || true)"
  if [ "$n" = "$4" ]; then ok "$1"; else bad "$1：出现 $n 次，期望 $4 次"; fi
}

# 待扫文件清单：本地直跑用 git 索引（只扫跟踪文件，未跟踪杂物不误报）；
# flake checks 的 store 副本无 .git，回退 find（flake 源=git 跟踪文件，等价）。
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  files="$(git -C "$REPO" ls-files)"
else
  files="$(cd "$REPO" && find . -type f -not -path './.git/*' | sed 's|^\./||')"
fi

# --- 自检：清单非空且覆盖 README（防空转通过）---
n_files="$(printf '%s\n' "$files" | grep -c . || true)"
if [ "$n_files" -gt 50 ]; then ok "文件清单非空（$n_files 个跟踪文件）"; else bad "文件清单异常（仅 $n_files 个，扫描逻辑坏了？）"; fi
case "$files" in
  *README.md*) ok "清单含 README.md" ;;
  *) bad "清单缺 README.md（扫描范围不对）" ;;
esac

# --- 主断言：可取用 URL 形式零容忍 ---
needle='gitee.com/qihaoxu/nixos-niri-noctalia'
violations=''
while IFS= read -r f; do
  case "$f" in
    docs/VALIDATION.md | tests/repo-references.sh) continue ;;
  esac
  if grep -qF "$needle" "$REPO/$f"; then
    violations="$violations $f"
  fi
done < <(printf '%s\n' "$files")

if [ -z "$violations" ]; then
  ok "旧名可取用 URL（$needle）零残留"
else
  bad "旧名可取用 URL 残留于：$violations（改为 nix-roam；识别旧检出的 alternation 除外）"
fi

# --- 计数断言：4 处既有检出识别 alternation 不被「顺手清理」---
alt="$(cat "$REPO"/bootstrap/*.sh 2>/dev/null)"
expect_count 'bootstrap 保留 4 处旧名检出识别 alternation' "$alt" "nixos-niri-noctalia|nix-roam" 4

# --- 自检：新名取用入口在位（改名后一键安装/克隆入口不得失踪）---
readme_body="$(cat "$REPO/README.md" 2>/dev/null)"
case "$readme_body" in
  *'gitee.com/qihaoxu/nix-roam/raw/master'*) ok "README 一键安装用新名 raw URL 在位" ;;
  *) bad "README 缺新名 raw URL（一键安装入口失踪）" ;;
esac

printf 'repo-references: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
