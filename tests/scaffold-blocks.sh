#!/usr/bin/env bash
# 脚手架样例块检查：bootstrap/nixos.sh 打印的 flake 输出块是对 flake.nix 结构的
# 无门复制，已漂移过一次（hostnameGuard 系 2026-09-28 手工补入）——此处以 grep 级
# 断言挡住「改 flake 忘改脚手架」类漂移。完整求值模拟是 VALIDATION 记载的手动
# 步骤（构建沙箱无 nix，进不了 checks）。
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

# 样例块正文：从「样例 A」标题行到 heredoc 结束符 EOF
body="$(sed -n '/---- flake.nix 输出块样例 A/,/^EOF$/p' "$REPO/bootstrap/nixos.sh")"
[ -n "$body" ] || { printf 'scaffold-blocks: 未找到样例块段（nixos.sh 打印段变了？）\n' >&2; exit 1; }

expect_count '样例块共两块（桌面 + CLI）' "$body" 'nixosConfigurations.__HOSTNAME__ = nixpkgs.lib.nixosSystem' 2
expect_count '两块都带 hostnameGuard 守卫' "$body" '(hostnameGuard "__HOSTNAME__")' 2
expect_count '桌面块用 home/default.nix' "$body" '(nixosHome ./home/default.nix)' 1
expect_count 'CLI 块用 home/nixos-cli.nix' "$body" '(nixosHome ./home/nixos-cli.nix)' 1
expect_count 'Hermes 只在桌面块' "$body" 'inputs.hermes-agent.nixosModules.default' 1
expect_count '每块接线 ./hosts/<target>（模块 + variables）' "$body" './hosts/__HOSTNAME__' 4

printf 'scaffold-blocks: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
