#!/usr/bin/env bash
# roam.sh 纯函数单测 —— source 方式加载被测脚本（分发段经 BASH_SOURCE 执行守卫跳过）。
# 覆盖最脆的解析点：home-manager generations 文本格式、profile 目录 glob、
# meta.json 提取、choose_inputs 交互解析、standalone_target 架构分发。
# 打桩手段：PATH 注入假 home-manager（cat fixture）、ROAM_SYSTEM_PROFILES_DIR
# 指向临时目录、source 前定义 uname 函数（kernel 在 source 期捕获）、stdin 管道。
# 运行：检出内 bash tests/roam-functions.sh；或经 flake checks
# （ROAM_TEST_REPO 指向仓库 store 副本，行为等价仅 PATH 不同）。
# 下列豁免均系打桩技术的固有误报：SC2030/SC2031——子 shell 内改
# PATH/HM_STUB_FILE 正是隔离手段，改动不外溢是本意；SC2329——uname 桩函数
# 经被测脚本（roam.sh 的 kernel 捕获与 standalone_target）间接调用。
# shellcheck disable=SC2030,SC2031,SC2329
set -u

REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
FIX="$REPO/tests/fixtures"
PASS=0
FAIL=0

command -v jq >/dev/null 2>&1 \
  || { printf 'roam-functions: 需要 jq（共享 CLI 列表自带；checks 环境由 nativeBuildInputs 提供）\n' >&2; exit 1; }

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1" >&2; }
expect_eq() { # 描述 got want
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1：got [$2] want [$3]"; fi
}
expect_rc() { # 描述 期望rc 实际rc
  if [ "$3" = "$2" ]; then ok "$1"; else bad "$1：rc=$3 want $2"; fi
}

# 加载被测函数；roam.sh 的 set -euo pipefail 会带上，断言逐条显式判 rc，关掉 errexit。
# shellcheck source=/dev/null
. "$REPO/packages/roam.sh"
set +e

# --- meta_username（meta.json 提取，解析失败须中止而非回落）---
out="$(cd "$FIX/meta-good" && meta_username)"; rc=$?
expect_rc 'meta_username：合法 meta.json rc=0' 0 "$rc"
expect_eq 'meta_username：取值' "$out" tester
out="$(cd "$FIX/meta-bad" && meta_username 2>/dev/null)"; rc=$?
expect_rc 'meta_username：缺 username 字段须拒绝' 1 "$rc"
out="$(cd "$REPO" && meta_username)"; rc=$?
expect_rc 'meta_username：仓库真实 meta.json rc=0' 0 "$rc"
expect_eq 'meta_username：仓库 username 非空' "$( [ -n "$out" ] && printf yes )" yes

# --- standalone_target（uname 打桩：kernel 在 source 期捕获，须在桩内重 source）---
stub_target() { # $1=uname -s $2=uname -m
  (
    STUB_S="$1"
    STUB_M="$2"
    uname() {
      case "$1" in
        -s) printf '%s\n' "$STUB_S" ;;
        -m) printf '%s\n' "$STUB_M" ;;
        *) printf 'stub\n' ;;
      esac
    }
    # shellcheck source=/dev/null
    . "$REPO/packages/roam.sh"
    standalone_target
  )
}
out="$(stub_target Linux x86_64)"; rc=$?
expect_rc 'standalone_target：Linux/x86_64 rc=0' 0 "$rc"
expect_eq 'standalone_target：Linux/x86_64' "$out" x86_64-linux
out="$(stub_target Linux aarch64)"; rc=$?
expect_rc 'standalone_target：Linux/aarch64 rc=0' 0 "$rc"
expect_eq 'standalone_target：Linux/aarch64' "$out" aarch64-linux
out="$(stub_target Linux arm64)"; rc=$?
expect_eq 'standalone_target：Linux/arm64 别名' "$out" aarch64-linux
out="$(stub_target Darwin arm64)"; rc=$?
expect_rc 'standalone_target：Darwin/arm64 rc=0' 0 "$rc"
expect_eq 'standalone_target：Darwin/arm64' "$out" aarch64-darwin
out="$(stub_target Darwin x86_64 2>/dev/null)"; rc=$?
expect_rc 'standalone_target：Intel Mac 须拒绝' 1 "$rc"
out="$(stub_target Linux riscv64 2>/dev/null)"; rc=$?
expect_rc 'standalone_target：未支持架构须拒绝' 1 "$rc"
out="$(stub_target SunOS x86_64 2>/dev/null)"; rc=$?
expect_rc 'standalone_target：未支持系统须拒绝' 1 "$rc"

# --- nixos_output（hostname 约定：目录名 = hostname = 输出属性名）---
out="$(
  uname() {
    [ "$1" = -n ] && printf 'wsl.example.com\n' || printf 'stub\n'
  }
  nixos_output
)"
expect_eq 'nixos_output：FQDN 取短名' "$out" 'nixosConfigurations.wsl'

# --- load_hm_generations（home-manager generations 文本解析；PATH 注入假命令）---
# stub 的 shebang 取 $BASH（当前 bash 的绝对路径）：构建沙箱没有 /usr/bin/env，
# 固定 #!/usr/bin/env bash 会让 stub 在 flake checks 里跑不起来（2026-09-28 实测）。
STUBBIN="$(mktemp -d)"
printf '#!%s\ncat "$HM_STUB_FILE"\n' "$BASH" > "$STUBBIN/home-manager"
chmod +x "$STUBBIN/home-manager"
out="$(
  PATH="$STUBBIN:$PATH"
  export HM_STUB_FILE="$FIX/hm-generations.txt"
  if load_hm_generations; then printf 'rc0\n'; else printf 'rc1\n'; fi
  printf 'current=%s\n' "$GEN_CURRENT"
  printf 'n=%s\n' "${#GEN_IDS[@]}"
  printf 'ids=%s\n' "${GEN_IDS[*]}"
  if [ "${GEN_PATHS[0]}" = "${GEN_PATHS[2]}" ]; then printf 'dup=same\n'; else printf 'dup=diff\n'; fi
)"
expect_eq 'load_hm_generations：fixture 全字段（含同路径重复世代）' "$out" 'rc0
current=0
n=5
ids=23 22 21 20 19
dup=same'
out="$(
  PATH="$STUBBIN:$PATH"
  export HM_STUB_FILE=/dev/null
  if load_hm_generations; then printf 'rc0\n'; else printf 'rc1\n'; fi
)"
expect_eq 'load_hm_generations：无世代/无 current 标记 → rc1' "$out" 'rc1'

# --- system_generation_ids（profile 目录 glob；ROAM_SYSTEM_PROFILES_DIR 打桩）---
PROF="$(mktemp -d)"
for n in 1 4 9 15; do : > "$PROF/system-$n-link"; done
: > "$PROF/system-xy-link"
: > "$PROF/system-2x-link"
: > "$PROF/system-99"
out="$(ROAM_SYSTEM_PROFILES_DIR="$PROF" system_generation_ids | tr '\n' ' ')"
expect_eq 'system_generation_ids：升序 + 噪声过滤' "${out% }" '1 4 9 15'
out="$(ROAM_SYSTEM_PROFILES_DIR="$PROF/empty" system_generation_ids)"
expect_eq 'system_generation_ids：空目录 → 空输出' "$out" ''

# --- choose_inputs（fixture flake.lock + stdin 打桩；菜单走 stderr 丢弃）---
choose() { # $1=模拟输入行；stdout=选定输入名（空=全部），rc 透传
  (
    cd "$FIX" || exit 9
    printf '%s\n' "$1" | choose_inputs 2>/dev/null
  )
}
sel="$(choose '' )"; rc=$?
expect_rc 'choose_inputs：回车 rc=0' 0 "$rc"
expect_eq 'choose_inputs：回车 → 空（=全部）' "$sel" ''
sel="$(choose '2')"; rc=$?
expect_rc 'choose_inputs：编号选择 rc=0' 0 "$rc"
expect_eq 'choose_inputs：编号 2 → 第二个输入名' "$sel" nixpkgs-stable
sel="$(choose '1 3')"; rc=$?
expect_eq 'choose_inputs：多编号空格分隔' "$sel" 'nixpkgs home-manager'
sel="$(choose 'nixpkgs, nixvim')"; rc=$?
expect_eq 'choose_inputs：名称逗号混用' "$sel" 'nixpkgs nixvim'
sel="$(choose '4, 1')"; rc=$?
expect_eq 'choose_inputs：编号逗号混用（输出按输入顺序）' "$sel" 'nixvim nixpkgs'
sel="$(choose '9' 2>/dev/null)"; rc=$?
expect_rc 'choose_inputs：越界编号须拒绝' 1 "$rc"
sel="$(choose 'bogus' 2>/dev/null)"; rc=$?
expect_rc 'choose_inputs：未知输入名须拒绝' 1 "$rc"

rm -rf "$STUBBIN" "$PROF"
printf 'roam-functions: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
