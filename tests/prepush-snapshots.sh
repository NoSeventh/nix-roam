#!/usr/bin/env bash
# 真 Git 多提交/标签 + 钩子主入口；默认 nix 桩，--real-nix 使用无输入最小 flake。
# 验证快照隔离、ref 去重、失败汇总和跳过路径，不触碰调用者的检出/配置/远端。
set -euo pipefail
REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0
REAL_NIX=''
case "${1:-}" in
  '') ;;
  --real-nix) REAL_NIX="$(command -v nix)" ;;
  *) printf '用法：prepush-snapshots.sh [--real-nix]\n' >&2; exit 1 ;;
esac
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/repo #?%"
mkdir -p "$WORK/subdir" "$TMP/bin"
git -C "$WORK" init -q -b master
cat >"$WORK/flake.nix" <<'EOF'
{
  outputs = { self }: let
    bad = builtins.readFile ./kind == "broken\n";
    localOverride = builtins.pathExists ./local.nixos.json;
    drv = if bad && !localOverride then throw "snapshot broken" else "/nix/store/fixture.drv";
  in {
    nixosConfigurations.nixos.config.system.build.toplevel.drvPath = drv;
    nixosConfigurations.wsl.config.system.build.toplevel.drvPath = "/nix/store/fixture.drv";
    homeConfigurations.x86_64-linux.activationPackage.drvPath = "/nix/store/fixture.drv";
    homeConfigurations.aarch64-linux.activationPackage.drvPath = "/nix/store/fixture.drv";
    homeConfigurations.aarch64-darwin.activationPackage.drvPath = "/nix/store/fixture.drv";
  };
}
EOF
printf 'local.*.json\n' >"$WORK/.gitignore"
commit() {
  git -C "$WORK" add .
  git -C "$WORK" -c user.name=Tester -c user.email=test@example.invalid \
    -c core.hooksPath=/dev/null commit -qm "$1"
  git -C "$WORK" rev-parse HEAD
}
printf 'good\n' >"$WORK/kind"
BASE="$(commit baseline)"
printf 'broken\n' >"$WORK/kind"
BROKEN="$(commit broken)"
printf 'good\n' >"$WORK/kind"
GOOD="$(commit fixed)"
printf 'documentation\n' >"$WORK/README.md"
DOCS="$(commit docs)"
git -C "$WORK" -c user.name=Tester -c user.email=test@example.invalid \
  tag -a release -m release "$GOOD"
TAG="$(git -C "$WORK" rev-parse release)"
# 分叉提交不是 HEAD 的祖先：真实 Nix 需要 allRefs 才能访问该分支快照。
git -C "$WORK" checkout -qb side "$BASE"
printf 'broken\n' >"$WORK/kind"
SIDE="$(commit 'side broken')"
git -C "$WORK" checkout -q master

# 工作树/索引里的修复以及 ignored local 选配不能把 BROKEN 快照救活。
printf 'dirty repair\n' >"$WORK/kind"
git -C "$WORK" add kind
printf '{"modules":[]}\n' >"$WORK/local.nixos.json"
LOG="$TMP/nix.log"
export LOG REAL_NIX
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
set -euo pipefail
[ "$1 $2" = 'eval --raw' ]
ref="$3"
case "$ref" in
  git+file://*\?rev=*\&allRefs=1\#*.drvPath) ;;
  *) printf 'unexpected unpinned/non-Git reference: %s\n' "$ref" >&2; exit 9 ;;
esac
revision="${ref#*\?rev=}"
revision="${revision%%&*}"
attr="${ref##*#}"
printf '%s %s\n' "$revision" "$attr" >>"$LOG"
if [ -n "$REAL_NIX" ]; then exec "$REAL_NIX" "$@"; fi
root="${ref#git+file://}"
root="${root%%\?*}"
root="${root//%20/ }"
root="${root//%23/#}"
root="${root//%3F/\?}"
root="${root//%25/%}"
kind="$(git -C "$root" show "$revision:kind")"
if [ "$kind" = broken ] && [ "$attr" = nixosConfigurations.nixos.config.system.build.toplevel.drvPath ]; then
  printf 'snapshot broken\n' >&2
  exit 4
fi
printf '/nix/store/fixture.drv'
EOF
} >"$TMP/bin/nix"
chmod +x "$TMP/bin/nix"
Z='0000000000000000000000000000000000000000'
MISSING='1111111111111111111111111111111111111111'
line() { printf '%s %s %s %s\n' "${3:-refs/heads/master}" "$1" "${3:-refs/heads/master}" "$2"; }
ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n%s\n' "$1" "${OUT:-}" >&2
}
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1：got [$2] want [$3]"; fi
}
run_hook() {
  : >"$LOG"
  if OUT="$(printf '%s\n' "$1" | (cd "$WORK/subdir" && PATH="$TMP/bin:$PATH" bash "$REPO/.githooks/pre-push") 2>&1)"; then
    RC=0
  else
    RC=$?
  fi
}
run_hook "$(line "$BROKEN" "$BASE")"
expect_eq 'snapshot：待推送坏提交被拦，HEAD/索引/工作树/local 的修复不掩盖' "$RC" 1
expect_eq 'snapshot：坏输出不截断其余四输出' "$(wc -l <"$LOG" | tr -d ' ')" 5
expect_eq 'snapshot：求值固定为协议里的 SHA' "$(cut -d ' ' -f1 "$LOG" | sort -u)" "$BROKEN"

printf 'broken\n' >"$WORK/kind"
git -C "$WORK" add kind
run_hook "$(line "$GOOD" "$BROKEN")"
expect_eq 'snapshot：工作树/索引的坏修改不污染好提交' "$RC" 0
expect_eq 'snapshot：好提交五输出齐全' "$(wc -l <"$LOG" | tr -d ' ')" 5
run_hook "$(line "$SIDE" "$BASE" refs/heads/side)
$(line "$GOOD" "$BROKEN" refs/heads/other)"
expect_eq 'snapshot：多 ref 任一失败即拦' "$RC" 1
expect_eq 'snapshot：失败后其它提交仍完整检查' "$(wc -l <"$LOG" | tr -d ' ')" 10
expect_eq 'snapshot：多 ref 含非 HEAD 祖先的分叉快照' "$(cut -d ' ' -f1 "$LOG" | sort -u)" "$(printf '%s\n%s\n' "$SIDE" "$GOOD" | sort)"
run_hook "$(line "$GOOD" "$BROKEN")
$(line "$GOOD" "$Z" refs/heads/other)
$(line "$TAG" "$Z" refs/tags/release)"
expect_eq 'snapshot：同 SHA 与 annotated tag 都可推送' "$RC" 0
expect_eq 'snapshot：同一 commit（含 tag peel）只求值五次' "$(wc -l <"$LOG" | tr -d ' ')" 5
run_hook "$(line "$DOCS" "$GOOD")
$(line "$Z" "$BASE" refs/heads/deleted)"
expect_eq 'snapshot：文档与删除 ref 放行' "$RC" 0
expect_eq 'snapshot：文档与删除不求值' "$(wc -l <"$LOG" | tr -d ' ')" 0
run_hook ''
expect_eq 'snapshot：空 stdin 放行' "$RC" 0
expect_eq 'snapshot：空 stdin 不求值' "$(wc -l <"$LOG" | tr -d ' ')" 0
run_hook "$(line "$GOOD" "$MISSING")"
expect_eq 'snapshot：远端 SHA 缺失仍检查本地快照' "$RC" 0
expect_eq 'snapshot：diff 失败保守检查五输出' "$(wc -l <"$LOG" | tr -d ' ')" 5
run_hook "$(line "$MISSING" "$Z")"
expect_eq 'snapshot：本地 SHA 缺失拦 push' "$RC" 1
expect_eq 'snapshot：本地 SHA 缺失不回退到 HEAD' "$(wc -l <"$LOG" | tr -d ' ')" 0
run_hook "$(line "$MISSING" "$Z")
$(line "$GOOD" "$BROKEN" refs/heads/other)"
expect_eq 'snapshot：无效本地 ref 与其它 ref 混合仍拦 push' "$RC" 1
expect_eq 'snapshot：本地 ref 缺失不截断其它提交检查' "$(wc -l <"$LOG" | tr -d ' ')" 5
printf 'prepush-snapshots: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
