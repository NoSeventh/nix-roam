#!/usr/bin/env bash
# roam.sh 纯函数单测 —— source 方式加载被测脚本（分发段经 BASH_SOURCE 执行守卫跳过）。
# 覆盖最脆的解析点：home-manager generations 文本格式、profile 目录 glob、
# meta.json 提取、choose_inputs 交互解析、read_flake_lock/flake.lock 缩进解析、
# standalone_target 架构分发、cmd_check 多目标分发与失败汇总。
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
expect_contains() { # 描述 haystack needle（空格定界——补全/旗标列表用）
  case " $2 " in
    *" $3 "*) ok "$1" ;;
    *) bad "$1：[$2] 不含 [$3]" ;;
  esac
}
expect_sub() { # 描述 haystack needle（无边界子串——路径内匹配用）
  case "$2" in
    *"$3"*) ok "$1" ;;
    *) bad "$1：[$2] 不含 [$3]" ;;
  esac
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

# --- nixos_preflight（nix 命令 PATH 打桩 + uname -n 函数打桩；短名=wsl）---
NIXSTUB="$(mktemp -d)"
# shellcheck disable=SC2016  # 单引号内 ${NIX_STUB_*} 系刻意字面量：stub 本体运行期展开
printf '#!%s\n[ -n "${NIX_STUB_FAIL:-}" ] && exit 1\nprintf "%%s\\n" "${NIX_STUB_HOSTNAME:-wsl}"\n' "$BASH" > "$NIXSTUB/nix"
chmod +x "$NIXSTUB/nix"
pfp() { # $1=假 nix 返回的 hostName；$2=fail 时让 nix 桩失败（模拟无对应输出）
  (
    PATH="$NIXSTUB:$PATH"
    export NIX_STUB_HOSTNAME="$1" NIX_STUB_FAIL="${2:-}"
    uname() {
      [ "$1" = -n ] && printf 'wsl.example.com\n' || printf 'stub\n'
    }
    nixos_preflight
  )
}
out="$(pfp wsl)"; rc=$?
expect_rc 'nixos_preflight：输出存在且 hostName 一致 rc=0' 0 "$rc"
out="$(pfp whatever fail 2>/dev/null)"; rc=$?
expect_rc 'nixos_preflight：无对应输出须拒绝' 1 "$rc"
out="$(pfp otherbox 2>/dev/null)"; rc=$?
expect_rc 'nixos_preflight：hostName 与输出名不一致须拒绝' 1 "$rc"

# --- load_hm_generations（home-manager generations 文本解析；PATH 注入假命令）---
# stub 的 shebang 取 $BASH（当前 bash 的绝对路径）：构建沙箱没有 /usr/bin/env，
# 固定 #!/usr/bin/env bash 会让 stub 在 flake checks 里跑不起来（2026-09-28 实测）。
STUBBIN="$(mktemp -d)"
# shellcheck disable=SC2016  # 单引号里的 $HM_STUB_FILE 是刻意的：stub 本体需字面量、其运行期才展开
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

# --- read_flake_lock / lock_date / cmd_flake（fixture + 仓库真实 flake.lock）---
out="$(
  cd "$FIX" || exit 9
  if read_flake_lock; then printf 'rc0\n'; else printf 'rc1\n'; fi
  printf 'roots=%s\n' "${ROOT_KEYS[*]}"
  printf 'nodes=%s\n' "${LOCK_NAMES[*]}"
  printf 'revs=%s\n' "${LOCK_REVS[*]}"
  printf 'epochs=%s\n' "${LOCK_EPOCHS[*]}"
  printf 'nrefs=%s\n' "${#LOCK_REFS[@]}"
)"
expect_eq 'read_flake_lock：fixture 全字段解析' "$out" 'rc0
roots=nixpkgs nixpkgs-stable home-manager nixvim
nodes=nixpkgs nixpkgs-stable home-manager nixvim
revs=1111111111111111111111111111111111111111 2222222222222222222222222222222222222222 3333333333333333333333333333333333333333 4444444444444444444444444444444444444444
epochs=1750000000 1750000001 1750000002 1750000003
nrefs=4'
out="$(
  cd "$REPO" || exit 9
  if read_flake_lock; then printf 'rc0\n'; else printf 'rc1\n'; fi
  printf 'roots=%s\n' "${ROOT_KEYS[*]}"
  printf 'nodes=%s\n' "${#LOCK_NAMES[@]}"
  printf 'rev40=%s/%s\n' "$(printf '%s\n' "${LOCK_REVS[@]}" | grep -c '^[0-9a-f]\{40\}$' || true)" "${#LOCK_NAMES[@]}"
  j=0
  while [ "$j" -lt "${#ROOT_KEYS[@]}" ]; do
    [ "${ROOT_KEYS[$j]}" = home-manager ] && printf 'hm_node=%s\n' "${ROOT_NODES[$j]}"
    j=$((j + 1))
  done
  case " ${LOCK_NAMES[*]} " in
    *" nixpkgs_2 "*) printf 'has_nixpkgs_2=yes\n' ;;
    *) printf 'has_nixpkgs_2=no\n' ;;
  esac
)"
expect_sub 'read_flake_lock：真实 lock 解析 rc0' "$out" 'rc0'
expect_eq 'read_flake_lock：真实 root 输入全集（lock 文件序）' \
  "$(printf '%s\n' "$out" | sed -n 's/^roots=//p')" \
  'hermes-agent home-manager nixos-wsl nixpkgs nixpkgs-stable nixvim'
# 节点数与 40 位 rev 完整性单独断言（sed 提取后算术比较）
nodes_n="$(printf '%s\n' "$out" | sed -n 's/^nodes=//p')"
if [ "${nodes_n:-0}" -gt 6 ]; then ok 'read_flake_lock：真实 lock 含传递节点'; else bad "read_flake_lock：传递节点缺失（nodes=${nodes_n}）"; fi
expect_eq 'read_flake_lock：rev 均为 40 位 hex' "$(printf '%s\n' "$out" | sed -n 's/^rev40=//p')" "$nodes_n/$nodes_n"
hm_node="$(printf '%s\n' "$out" | sed -n 's/^hm_node=//p')"
case "$hm_node" in
  home-manager*) ok "read_flake_lock：home-manager 指向后缀节点（$hm_node）" ;;
  *) bad "read_flake_lock：home-manager 映射异常：[$hm_node]" ;;
esac
expect_eq 'read_flake_lock：nixvim 自带 nixpkgs_2 在节点表' "$(printf '%s\n' "$out" | sed -n 's/^has_nixpkgs_2=//p')" yes
BADLOCK="$(mktemp -d)"
: >"$BADLOCK/flake.lock"
out="$(cd "$BADLOCK" && read_flake_lock 2>/dev/null)"; rc=$?
expect_rc 'read_flake_lock：空 lock 须拒绝（fail-loud）' 1 "$rc"
rm -rf "$BADLOCK"
expect_eq 'lock_date：epoch → UTC 日期（GNU/BSD 双语法其一）' "$(lock_date 1750000000)" 2025-06-15
expect_eq 'lock_date：epoch 0' "$(lock_date 0)" 1970-01-01
expect_eq 'lock_date：空 epoch → -' "$(lock_date '')" -
flk() { # fixture 下跑 cmd_flake（repo_check 打桩——fixture 目录无 flake.nix/meta.json）
  (
    cd "$FIX" || exit 9
    repo_check() { :; }
    cmd_flake "$@"
  )
}
out="$(flk)"; rc=$?
expect_rc 'cmd_flake：fixture rc=0' 0 "$rc"
expect_sub 'cmd_flake：表头' "$out" 'flake 输入（flake.lock 锁定'
expect_eq 'cmd_flake：fixture 表内容（空白归一）' "$(printf '%s\n' "$out" | grep '^  ' | sed 's/^ *//' | tr -s ' ')" 'nixpkgs 1111111 2025-06-15 - -
nixpkgs-stable 2222222 2025-06-15 - -
home-manager 3333333 2025-06-15 - -
nixvim 4444444 2025-06-15 - -'
out="$(flk --all)"; rc=$?
expect_rc 'cmd_flake：--all rc=0' 0 "$rc"
expect_sub 'cmd_flake：--all 传递输入头（fixture 无传递节点，仅头行）' "$out" '传递输入（上游 flake 自带锁定'
out="$(flk -a)"; rc=$?
expect_rc 'cmd_flake：-a 短旗标 rc=0' 0 "$rc"
expect_sub 'cmd_flake：-a 等价 --all' "$out" '传递输入（上游 flake 自带锁定'
out="$(cd "$REPO" && cmd_flake)"; rc=$?
expect_rc 'cmd_flake：仓库真实 lock rc=0' 0 "$rc"
for k in hermes-agent home-manager nixos-wsl nixpkgs nixpkgs-stable nixvim; do
  expect_contains "cmd_flake：真实表含 $k" "$out" "$k"
done
out="$(cd "$REPO" && cmd_flake --all)"; rc=$?
expect_rc 'cmd_flake：真实 --all rc=0' 0 "$rc"
expect_contains 'cmd_flake：--all 含 nixvim 自带 nixpkgs_2' "$out" nixpkgs_2
out="$(flk --bogus 2>/dev/null)"; rc=$?
expect_rc 'cmd_flake：未知选项须拒绝' 1 "$rc"
out="$(flk extra 2>/dev/null)"; rc=$?
expect_rc 'cmd_flake：位置参数须拒绝' 1 "$rc"

# --- cmd_gc（假 nix-collect-garbage / sudo 经 PATH 打桩，调用参数落 GC_LOG）---
STUBGC="$(mktemp -d)"
GCLOG_FILE="$(mktemp)"
# shellcheck disable=SC2016  # 单引号内 $* / $GC_LOG 系刻意字面量：stub 本体运行期展开
printf '#!%s\nprintf "%%s\\n" "$*" >> "$GC_LOG"\n' "$BASH" > "$STUBGC/nix-collect-garbage"
# shellcheck disable=SC2016  # 同上
printf '#!%s\nprintf "sudo %%s\\n" "$*" >> "$GC_LOG"\n' "$BASH" > "$STUBGC/sudo"
chmod +x "$STUBGC/nix-collect-garbage" "$STUBGC/sudo"
# is_nixos 桩：宿主探测必须固定，否则用例语义随真机漂移（在真 NixOS 上跑
# standalone 断言会假失败——无旗标也自动 --system 调 sudo）
gcr() { # standalone 语义跑 cmd_gc，调用记录落 GCLOG_FILE
  (
    PATH="$STUBGC:$PATH"
    export GC_LOG="$GCLOG_FILE"
    is_nixos() { return 1; }
    : >"$GC_LOG"
    cmd_gc "$@"
  )
}
gcr_nixos() { # NixOS 语义（自动 --system）：无旗标也须先用户后 sudo 系统侧
  (
    PATH="$STUBGC:$PATH"
    export GC_LOG="$GCLOG_FILE"
    is_nixos() { return 0; }
    : >"$GC_LOG"
    cmd_gc "$@"
  )
}
out="$(gcr --dry-run)"; rc=$?
expect_rc 'gc：--dry-run rc=0' 0 "$rc"
expect_sub 'gc：dry-run 打印命令（gc_bin 为桩路径）' "$out" 'nix-collect-garbage --delete-older-than 14d'
expect_eq 'gc：dry-run 不执行' "$(cat "$GCLOG_FILE")" ''
out="$(gcr)"; rc=$?
expect_rc 'gc：缺省 rc=0' 0 "$rc"
expect_contains 'gc：缺省 14d 用户侧' "$(cat "$GCLOG_FILE")" '--delete-older-than 14d'
expect_eq 'gc：无 --system 不调 sudo' "$(grep -c sudo "$GCLOG_FILE" || true)" '0'
out="$(gcr --older-than 30d)"; rc=$?
expect_rc 'gc：--older-than 30d rc=0' 0 "$rc"
expect_contains 'gc：期限透传' "$(cat "$GCLOG_FILE")" '--delete-older-than 30d'
out="$(gcr --all)"; rc=$?
expect_rc 'gc：--all rc=0' 0 "$rc"
expect_contains 'gc：--all → --delete-old' "$(cat "$GCLOG_FILE")" --delete-old
out="$(gcr --system)"; rc=$?
expect_rc 'gc：--system rc=0' 0 "$rc"
expect_contains 'gc：--system 用户侧先清' "$(head -n 1 "$GCLOG_FILE")" '--delete-older-than 14d'
expect_contains 'gc：--system sudo 侧后清' "$(tail -n 1 "$GCLOG_FILE")" 'sudo -H --'
out="$(gcr_nixos)"; rc=$?
expect_rc 'gc：NixOS 无旗标 rc=0' 0 "$rc"
expect_contains 'gc：NixOS 自动 --system：用户侧先清' "$(head -n 1 "$GCLOG_FILE")" '--delete-older-than 14d'
expect_contains 'gc：NixOS 自动 --system：sudo 侧后清' "$(tail -n 1 "$GCLOG_FILE")" 'sudo -H --'
out="$(gcr_nixos --dry-run)"; rc=$?
expect_rc 'gc：NixOS dry-run rc=0' 0 "$rc"
expect_eq 'gc：NixOS dry-run 不执行（含 sudo 侧）' "$(cat "$GCLOG_FILE")" ''
out="$(gcr --help)"; rc=$?
expect_rc 'gc：--help rc=0' 0 "$rc"
expect_contains 'gc：--help 出用法' "$out" '用法：roam gc'
# 拒绝路径（参数组刻意经词切分展开）
# shellcheck disable=SC2086
for badargs in '--older-than 0d' '--older-than x' '--all --older-than 30d' '--older-than' '--bogus'; do
  out="$(gcr $badargs 2>/dev/null)"; rc=$?
  expect_rc "gc：[$badargs] 须拒绝" 1 "$rc"
done

# --- cmd_check（多目标；nix 函数桩记录调用、失败按 FAIL_ATTR 注入；
# cd 仓库根满足 repo_check。宿主探测钉死：is_nixos/uname 桩——缺省目标的
# host_attr 走真实探测会随宿主漂移）---
CHECK_LOG="$(mktemp)"
FAIL_ATTR=''
ckr() {
  (
    cd "$REPO" || exit 1
    : >"$CHECK_LOG"
    nix() {
      printf '%s\n' "$*" >>"$CHECK_LOG"
      # 失败注入仅在 FAIL_ATTR 非空时启用：空串作 case 模式等价 **（匹配一切），
      # 曾使全部桩调用假失败（本批新增用例首跑实测）
      if [ -n "$FAIL_ATTR" ]; then
        case "$*" in
          *"$FAIL_ATTR"*) return 4 ;;
        esac
      fi
      return 0
    }
    is_nixos() { return 1; }
    uname() {
      case "$1" in
        -m) printf '%s\n' x86_64 ;;
        *) command uname "$@" ;;
      esac
    }
    cmd_check "$@"
  )
}
out="$(ckr wsl nixos)"; rc=$?
expect_rc 'check：多目标 rc=0' 0 "$rc"
# 并行求值：nix 桩在后台子壳里竞争写日志，完成次序不定——排序比对
expect_eq 'check：多目标都求值（并行次序不定，排序比对）' "$(sort "$CHECK_LOG")" \
  'eval --raw .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
eval --raw .#nixosConfigurations.wsl.config.system.build.toplevel.drvPath'
# 汇报在全部完成后按输入次序打印（稳定可测），头行次序即输入次序
expect_eq 'check：汇报次序=输入次序' "$(printf '%s\n' "$out" | grep '^roam check: 求值')" \
  'roam check: 求值 .#nixosConfigurations.wsl.config.system.build.toplevel
roam check: 求值 .#nixosConfigurations.nixos.config.system.build.toplevel'
expect_sub 'check：多目标通过汇总行' "$out" '2 个目标全部通过'
expect_sub 'check：多目标并行预告行' "$out" '并行求值 2 个目标'
out="$(ckr wsl wsl)"; rc=$?
expect_rc 'check：重复目标去重 rc=0' 0 "$rc"
expect_eq 'check：重复目标只跑一次' "$(grep -c . "$CHECK_LOG" || true)" 1
expect_eq 'check：单目标不打汇总行' "$(printf '%s' "$out" | grep -c '个目标' || true)" 0
out="$(ckr x86_64-linux --build)"; rc=$?
expect_rc 'check：--build 可后置 rc=0' 0 "$rc"
expect_eq 'check：--build 走构建命令' "$(cat "$CHECK_LOG")" \
  'build --no-link .#homeConfigurations.x86_64-linux.activationPackage'
out="$(ckr)"; rc=$?
expect_rc 'check：缺省目标 rc=0（standalone 桩）' 0 "$rc"
expect_contains 'check：缺省=当前宿主（x86_64-linux）' "$(cat "$CHECK_LOG")" \
  'eval --raw .#homeConfigurations.x86_64-linux.activationPackage.drvPath'
out="$(ckr bogus 2>/dev/null)"; rc=$?
expect_rc 'check：未知目标须拒绝' 1 "$rc"
errout="$(ckr bogus 2>&1)"
expect_sub 'check：未知目标报错点名' "$errout" '未知目标：bogus'
out="$(ckr --bogus 2>/dev/null)"; rc=$?
expect_rc 'check：未知选项须拒绝' 1 "$rc"
FAIL_ATTR='nixosConfigurations.wsl'
out="$(ckr wsl nixos 2>/dev/null)"; rc=$?
expect_rc 'check：任一目标失败 rc=1' 1 "$rc"
expect_eq 'check：失败不中断，两目标都跑' "$(grep -c . "$CHECK_LOG" || true)" 2
errout="$(ckr wsl nixos 2>&1)"
expect_sub 'check：失败汇总行' "$errout" '存在失败目标'
FAIL_ATTR=''

rm -rf "$STUBBIN" "$PROF" "$NIXSTUB" "$STUBGC" "$GCLOG_FILE" "$CHECK_LOG"
printf 'roam-functions: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
