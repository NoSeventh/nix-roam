#!/usr/bin/env bash
# 注册表一致性门禁：modules/registry.json 是模块选配的单一事实源（flake 的
# lib/selection.nix 与 roam.sh load_registry 两路消费），本关卡钉住它与仓库实态
# 互相不漂移：
#   1. roam 的解析结果与注册表字段交叉核对（名字与三面旗标逐一相等）——
#      解析输出与文件内容不一致时当场暴露；
#   2. 旗标与文件实态互证：nixos/home=true 的层必有对应实现文件，false 的层
#      不得有 home.nix（有文件却标 false = 静默不可达，最危险的漂移形态）；
#   3. 反向：modules/ 下每个层目录都在注册表里（desktop/ 基座除外）；
#   4. 配套钩子：.gitignore 收录 local.*.json；桌面基座四件在位。
# 需要 jq（checks 环境由 nativeBuildInputs 提供，与 roam-functions.sh 同立场）。
set -u

REPO="${ROAM_TEST_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1" >&2; }

command -v jq >/dev/null 2>&1 \
  || { printf 'module-registry: 需要 jq\n' >&2; exit 1; }

REG="$REPO/modules/registry.json"
[ -f "$REG" ] || { printf 'module-registry: 缺 %s\n' "$REG" >&2; exit 1; }

# 1. roam 命令库解析结果 vs 注册表字段
# shellcheck source=/dev/null
. "$REPO/packages/roam.sh"
set +e
load_registry "$REG"
i=0
while [ "$i" -lt "${#REG_NAMES[@]}" ]; do
  name="${REG_NAMES[$i]}"
  jq_nixos="$(jq -r --arg n "$name" '.modules[] | select(.name==$n) | .nixos' "$REG")"
  jq_home="$(jq -r --arg n "$name" '.modules[] | select(.name==$n) | .home' "$REG")"
  jq_darwin="$(jq -r --arg n "$name" '.modules[] | select(.name==$n) | .darwin' "$REG")"
  if [ "${REG_NIXOS[$i]}" = "$jq_nixos" ] && [ "${REG_HOME[$i]}" = "$jq_home" ] && [ "${REG_DARWIN[$i]}" = "$jq_darwin" ]; then
    ok "解析交叉核对：$name（nixos/home/darwin 三面旗标 bash=jq）"
  else
    bad "解析交叉核对：$name bash=[${REG_NIXOS[$i]}/${REG_HOME[$i]}/${REG_DARWIN[$i]}] jq=[$jq_nixos/$jq_home/$jq_darwin]"
  fi
  # 2. 旗标与文件实态互证
  if [ "${REG_NIXOS[$i]}" = true ]; then
    if [ -f "$REPO/modules/$name/nixos.nix" ]; then ok "$name：nixos.nix 在位"; else bad "$name：nixos=true 但缺 modules/$name/nixos.nix"; fi
  fi
  if [ "${REG_HOME[$i]}" = true ]; then
    if [ -f "$REPO/modules/$name/home.nix" ]; then ok "$name：home.nix 在位"; else bad "$name：home=true 但缺 modules/$name/home.nix"; fi
  elif [ -f "$REPO/modules/$name/home.nix" ]; then
    bad "$name：home=false 却存在 home.nix（静默不可达；改旗标或删文件）"
  else
    ok "$name：home=false 无 home.nix（一致）"
  fi
  i=$((i + 1))
done

# 3. 反向：层目录全数在册
for d in "$REPO"/modules/*/; do
  name="$(basename "$d")"
  [ "$name" = desktop ] && continue # 桌面基座（session/niri/core/locale-zh），非可选层
  if jq -e --arg n "$name" '.modules[] | select(.name==$n)' "$REG" >/dev/null; then
    ok "层目录在册：$name"
  else
    bad "层目录未入注册表：modules/$name/（无名额=roam/selection 两路都看不见）"
  fi
done

# 4. 配套钩子
if grep -q '^local\.\*\.json$' "$REPO/.gitignore"; then
  ok '.gitignore 收录 local.*.json'
else
  bad '.gitignore 缺 local.*.json 条目'
fi
for f in session.nix niri.nix core.nix locale-zh.nix; do
  if [ -f "$REPO/modules/desktop/$f" ]; then ok "桌面基座在位：$f"; else bad "桌面基座缺失：modules/desktop/$f"; fi
done

printf 'module-registry: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
