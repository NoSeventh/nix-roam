#!/usr/bin/env bash
# bootstrap/linux.sh 提权前端单测 —— run_as_root / su_root 用 sed 提取加载
# （linux.sh 不可整体 source：仓库定位段即开始执行安装）。
# 覆盖最脆的点：sudo/su/皆无 三分派、非终端 stdin 拒走 su（交互安全，curl|bash
# 不会卡密码提示）、su_root 的 %q 拼串往返（元字符参数经 root shell 解析须还原为
# 同一 argv）、rc 透传。
# 打桩手段：PATH 前置假 sudo/su（argv 逐行落盘，rc 由 STUB_RC 控制；宿主真装有
# sudo 也不影响——分派由重定义的 have 桩决定，命令解析由前置 PATH 决定）。
# 下列豁免均系打桩技术的固有误报：SC2030/SC2031——子 shell 内改 PATH/STUB_* 正是
# 隔离手段，改动不外溢是本意；SC2329——have 桩函数（各用例内的分派桩）经被测脚本
# （run_as_root）间接调用；SC2016——两个 printf 生成 stub 的单引号格式串里
# ${STUB_*}/$@ 系刻意字面量，stub 本体运行期才展开。
# shellcheck disable=SC2030,SC2031,SC2329,SC2016
set -u

REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1" >&2; }
expect_rc() { # 描述 期望rc 实际rc
  if [ "$3" = "$2" ]; then ok "$1"; else bad "$1：rc=$3 want $2"; fi
}
expect_eq() { # 描述 got want
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1：got [$2] want [$3]"; fi
}

# 提取被测函数：linux.sh 顶格多行函数体（首行 ^name() {、尾行 ^}）。
# have() 是单行定义提不出来，测试本地等价重定义——run_as_root 引用的正是这个名字，
# 分派用例在子 shell 里按需覆盖成桩。
FUNCS="$(sed -n '/^run_as_root()/,/^}/p; /^su_root()/,/^}/p' "$REPO/bootstrap/linux.sh")"
case "$FUNCS" in
  *run_as_root*su_root*) ;;
  *) printf 'bootstrap-helpers: 从 linux.sh 提取 run_as_root/su_root 失败（函数改成单行或改名了？）\n' >&2; exit 1 ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 假 sudo / 假 su：argv 逐参数一行落盘（sudo 记 $@；su 只认 -c 单串，记 $2），rc=STUB_RC。
# shebang 用 $BASH 绝对路径而非 #!/usr/bin/env bash——nix build 沙箱没有 /usr/bin/env
# （roam-functions.sh 假 nix 同款手法；本地能跑沙箱炸的坑，2026-10-05 沙箱实测再证）。
mkdir -p "$WORK/bin"
printf '#!%s\nprintf "%%s\\n" "$@" >> "${STUB_LOG:?}.sudo"\nexit "${STUB_RC:-0}"\n' "$BASH" > "$WORK/bin/sudo"
printf '#!%s\nif [ "$1" != "-c" ] || [ $# -ne 2 ]; then\n  printf "su-stub: 只支持 -c <单串>（got %%s 个参数）\\n" "$#" >&2\n  exit 9\nfi\nprintf "%%s\\n" "$2" >> "${STUB_LOG:?}.su"\nexit "${STUB_RC:-0}"\n' "$BASH" > "$WORK/bin/su"
chmod +x "$WORK/bin/sudo" "$WORK/bin/su"

have() { command -v "$1" >/dev/null 2>&1; }  # 与 linux.sh 同名同义
# shellcheck source=/dev/null
eval "$FUNCS"

# --- run_as_root 分派：have sudo → 命令原样转发 sudo ---
(
  have() { [ "$1" = sudo ]; }
  PATH="$WORK/bin:$PATH"; export PATH
  STUB_LOG="$WORK/a"; export STUB_LOG
  run_as_root echo hi
); rc=$?
expect_rc 'run_as_root：有 sudo 时 rc=0（转发成功）' 0 "$rc"
expect_eq 'run_as_root：sudo 收到原样 argv' "$(tr '\n' ' ' < "$WORK/a.sudo")" "echo hi "

# --- run_as_root 分派：sudo 非零退出 → 原样透传（不吞错）---
(
  have() { [ "$1" = sudo ]; }
  PATH="$WORK/bin:$PATH"; export PATH
  STUB_LOG="$WORK/b"; STUB_RC=7; export STUB_LOG STUB_RC
  run_as_root true
); rc=$?
expect_rc 'run_as_root：sudo 失败 rc 透传' 7 "$rc"

# --- run_as_root 分派：sudo/su 皆无 → rc=1（fail-loud 由调用方负责）---
(
  have() { return 1; }
  run_as_root true
); rc=$?
expect_rc 'run_as_root：sudo/su 皆无 rc=1' 1 "$rc"

# --- run_as_root 分派：无 sudo 有 su、stdin 非终端 → 拒走 su ---
#     （< /dev/null 钉死非终端：交互终端直跑本文件时 [ -t 0 ] 为真会假失败——
#      断言不得隐含宿主 tty 状态，VALIDATION 惯例；正路径 tty+su 由 su_root 直测拼串覆盖）
(
  have() { [ "$1" = su ]; }
  PATH="$WORK/bin:$PATH"; export PATH
  STUB_LOG="$WORK/c"; export STUB_LOG
  run_as_root true < /dev/null
); rc=$?
expect_rc 'run_as_root：无 sudo、stdin 非终端 → 拒走 su rc=1' 1 "$rc"
if [ -f "$WORK/c.su" ]; then bad 'run_as_root：非终端不应调用 su'; else ok 'run_as_root：非终端未调用 su'; fi

# --- su_root 拼串：su -c 收到单个命令串，经 shell 解析还原同一 argv ---
(
  PATH="$WORK/bin:$PATH"; export PATH
  STUB_LOG="$WORK/d"; export STUB_LOG
  su_root echo "a b" 'c&&d'
); rc=$?
expect_rc 'su_root：rc 透传（stub rc=0）' 0 "$rc"
sent="$(cat "$WORK/d.su" 2>/dev/null)"
if [ -n "$sent" ]; then
  ok 'su_root：su -c 收到单串'
  # eval 重解析即 root shell 对 su -c 串做的事：%q 转义往返须还原原参数
  # shellcheck disable=SC2294  # 被测性质就是「这一串可安全重解析」
  eval "set -- $sent"
  expect_eq 'su_root：解析还原 argv（命令）' "$1" echo
  expect_eq 'su_root：解析还原 argv（含空格参数）' "$2" 'a b'
  expect_eq 'su_root：解析还原 argv（含元字符参数）' "$3" 'c&&d'
else
  bad 'su_root：su 未被调用（stub 日志缺失）'
fi

# --- su_root：su 非零退出 → 原样透传 ---
(
  PATH="$WORK/bin:$PATH"; export PATH
  STUB_LOG="$WORK/e"; STUB_RC=3; export STUB_LOG STUB_RC
  su_root true
); rc=$?
expect_rc 'su_root：su 失败 rc 透传' 3 "$rc"

printf 'bootstrap-helpers: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
