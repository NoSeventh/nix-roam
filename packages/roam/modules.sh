#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034
# 模块选择：注册表与 local 文件均使用 jq，路径约定与 lib/selection.nix 一致。
registry_path() { printf '%s' "${ROAM_REGISTRY_PATH:-modules/registry.json}"; }
local_file() { printf '%s/local.%s.json' "${ROAM_LOCAL_DIR:-.}" "$1"; }

# 填平行数组 REG_NAMES / REG_NIXOS / REG_HOME / REG_DARWIN / REG_DESC。
load_registry() {
  require_jq
  REG_NAMES=()
  REG_NIXOS=()
  REG_HOME=()
  REG_DARWIN=()
  REG_DESC=()
  local f="$1" rows name nixos home darwin desc
  [ -f "$f" ] || die "未找到注册表 $f（须在仓库检出目录运行）"
  rows="$(jq -ser 'if length == 1 then .[0] else error("expected one JSON document") end |
    if type == "object" and .version == 1 and
       (.modules | type == "array" and length > 0) and
       all(.modules[];
         (.name | type == "string" and test("^[a-z][a-z0-9-]*$")) and
         ((.nixos // false) | type == "boolean") and
         ((.home // false) | type == "boolean") and
         ((.darwin // false) | type == "boolean") and
         ((.desc // "") | type == "string")) and
       ([.modules[].name] | length == (unique | length))
    then .modules[] | [.name, (.nixos // false), (.home // false),
                          (.darwin // false), (.desc // "")] | @tsv
    else error("invalid module registry") end
  ' "$f")" || die "注册表 $f 格式无效（version=1、非空模块列表、唯一合法名字与布尔旗标）"
  while IFS=$'\t' read -r name nixos home darwin desc; do
    REG_NAMES+=("$name")
    REG_NIXOS+=("$nixos")
    REG_HOME+=("$home")
    REG_DARWIN+=("$darwin")
    REG_DESC+=("$desc")
  done <<EOF
$rows
EOF
}

# 模块名 → REG_* 下标；找不到返回 1（调用方给文案）
module_lookup() {
  local i=0
  while [ "$i" -lt "${#REG_NAMES[@]}" ]; do
    if [ "${REG_NAMES[$i]}" = "$1" ]; then
      REG_IDX=$i
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# 主机键 → 前端：standalone 三键按名映射，其余视为 NixOS 主机名（hosts/<K>/ 须在）。
# darwin 键走 home-darwin（白名单在 selection.nix 与本文件 enable 校验双重把守）。
module_front_for_key() {
  case "$1" in
    x86_64-linux | aarch64-linux) printf 'home-linux' ;;
    aarch64-darwin) printf 'home-darwin' ;;
    *)
      [ -d "hosts/$1" ] || die "未知主机键：$1（NixOS 主机须有 hosts/<主机名>/ 目录；standalone 键：x86_64-linux / aarch64-linux / aarch64-darwin）"
      printf 'nixos'
      ;;
  esac
}

# 当前宿主的主机键（与 nixos_output / standalone_target 同源约定）
module_current_key() {
  if is_nixos; then
    local h
    h="$(uname -n)"
    printf '%s' "${h%%.*}"
  else
    standalone_target
  fi
}

# 接受合法 JSON 的任意排版；写入前拒绝坏文件和错机文件，避免静默覆盖。
local_selection_read() {
  local f names
  f="$(local_file "$1")"
  [ -f "$f" ] || return 1
  require_jq
  names="$(jq -ser --arg key "$1" 'if length == 1 then .[0] else error("expected one JSON document") end |
    if type == "object" and
       (if has("host") then .host == $key else true end) and
       (.modules | type == "array") and
       all(.modules[]; type == "string" and test("^[a-z][a-z0-9-]*$"))
    then .modules | join("\n")
    else error("invalid selection or host mismatch") end
  ' "$f")" || die "选配文件 $f 无效（modules 须为模块名数组，host 须与 $1 一致）"
  printf '%s' "$names"
}

# 按自持格式写选配文件（host 自校验字段 + updated 时间戳 + 每模块一行）。
# 末元素不带尾逗号——文件须是严格合法 JSON（nix fromJSON 不容忍）。
local_selection_write() {
  local k="$1" f tmp m i=1 total
  shift
  total=$#
  f="$(local_file "$k")"
  tmp="${f}.tmp"
  {
    printf '{\n'
    printf '  "host": "%s",\n' "$k"
    printf '  "updated": "%s",\n' "$(date '+%F %T')"
    printf '  "modules": ['
    if [ "$total" -gt 0 ]; then
      printf '\n'
      for m in "$@"; do
        if [ "$i" -lt "$total" ]; then
          printf '    "%s",\n' "$m"
        else
          printf '    "%s"\n' "$m"
        fi
        i=$((i + 1))
      done
    else
      printf '\n'
    fi
    printf '  ]\n}\n'
  } >"$tmp" && mv "$tmp" "$f"
}

# 当前有效选择（local 缺席时 = 入库默认集）：一次轻求值，每行一个名字。
# 求值失败（如 local 文件本身坏）原样透传 rc，调用方给文案。
effective_selection() {
  local k="$1" front="$2" attr
  case "$front" in
    nixos) attr="nixosConfigurations.${k}" ;;
    *) attr="homeConfigurations.${k}" ;;
  esac
  nix eval --raw --apply 'xs: builtins.concatStringsSep "\n" xs' \
    "path:./.#${attr}.config.roam.selectedModules"
}

sel_has() { printf '%s\n' "$1" | grep -qxF "$2"; }

module_usage() {
  cat <<'EOF'
用法：roam module <动作> [名...] [--host K]

  init               生成 local.<主机键>.json（以当前有效选择为种子，首次零行为变化）
  list               注册表目录 + 该机 on/off（--host K 看其它主机键）
  enable <名...>     启用模块（未知名 / 前端不适用 / darwin 白名单外 → 拒绝）
  disable <名...>    停用模块（未启用为幂等 no-op）
  -h, --help         显示本帮助

主机键：NixOS = 主机名（hosts/<主机名>/）；standalone = 输出名
（x86_64-linux / aarch64-linux / aarch64-darwin）。缺省 = 当前宿主。
选配文件 gitignored、只记本机；git 求值视图（CI/远端）见入库默认集。
改完 roam check <K> 验证，roam switch 生效。
EOF
}

cmd_module() {
  local action='' host_key='' names='' n k front f seed cur changed new_name
  [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { module_usage; return 0; }
  [ "$#" -ge 1 ] || { module_usage >&2; die 'module: 缺少动作（init / list / enable / disable）'; }
  action="$1"
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --host)
        [ "$#" -ge 2 ] || die 'module: --host 需要参数（主机键）'
        host_key="$2"
        shift 2
        continue
        ;;
      -h | --help) module_usage; return 0 ;;
      -*) die "module: 未知选项：$1" ;;
      *) names="$names $1" ;;
    esac
    shift
  done
  names="${names# }"
  [ -n "${ROAM_REGISTRY_PATH:-}" ] || repo_check
  load_registry "$(registry_path)"
  [ -n "$host_key" ] || host_key="$(module_current_key)"
  front="$(module_front_for_key "$host_key")"
  f="$(local_file "$host_key")"
  case "$action" in
    init)
      [ -z "$names" ] || die 'module init 不接受模块名（种子 = 当前有效选择）'
      [ -f "$f" ] && die "已存在 $f（要调整用 enable/disable；要重来先删文件）"
      seed="$(effective_selection "$host_key" "$front")" \
        || die "当前有效选择求值失败（$host_key 输出不可求值？修好后再 init）"
      # shellcheck disable=SC2086
      local_selection_write "$host_key" $seed
      printf 'roam: 已生成 %s（%s 层，种子 = 当前有效选择，行为无变化）\n' "$f" "$(printf '%s\n' "$seed" | grep -c . || true)"
      ;;
    list)
      local on eff=''
      if eff="$(effective_selection "$host_key" "$front")"; then
        :
      else
        printf 'roam: ! 有效选择求值失败（local 文件坏或输出不可求值），on/off 列不可用\n' >&2
        eff=''
      fi
      if [ -f "$f" ]; then
        printf '主机键 %s（前端 %s）· 本机选配 %s（%s 层启用）\n' "$host_key" "$front" "$f" "$(printf '%s\n' "$eff" | grep -c . || true)"
      else
        printf '主机键 %s（前端 %s）· 无本机选配（入库默认集）\n' "$host_key" "$front"
      fi
      printf '%-4s %-18s %-22s %s\n' 'on?' '模块' '前端' '说明'
      n=0
      while [ "$n" -lt "${#REG_NAMES[@]}" ]; do
        if sel_has "$eff" "${REG_NAMES[$n]}"; then on='✓'; else on='·'; fi
        printf '%-4s %-18s %-22s %s\n' "$on" "${REG_NAMES[$n]}" \
          "nixos:${REG_NIXOS[$n]} home:${REG_HOME[$n]} darwin:${REG_DARWIN[$n]}" "${REG_DESC[$n]}"
        n=$((n + 1))
      done
      printf '基座（nixos-base / 桌面基座 / cli-dev CLI 列表）不在此列、不可关。\n'
      ;;
    enable | disable)
      [ -n "$names" ] || die "module $action: 至少给一个模块名（roam module list 查看）"
      # 校验全部名字后再动文件（要么全成、要么不动）
      # shellcheck disable=SC2086
      for new_name in $names; do
        module_lookup "$new_name" \
          || die "模块 $new_name 不在注册表（roam module list 查看；名字以 modules/registry.json 为准）"
        case "$front" in
          nixos)
            [ "${REG_NIXOS[$REG_IDX]}" = true ] \
              || die "模块 $new_name 无 nixos 实现（其用户级能力也不适用于 NixOS 系统级前端）"
            ;;
          home-linux)
            [ "${REG_HOME[$REG_IDX]}" = true ] \
              || die "模块 $new_name 无 home-linux 实现（系统级专属层，standalone 不可启用）"
            ;;
          home-darwin)
            [ "${REG_HOME[$REG_IDX]}" = true ] \
              || die "模块 $new_name 无用户级实现（standalone 不可启用）"
            [ "${REG_DARWIN[$REG_IDX]}" = true ] \
              || die "模块 $new_name 不在 darwin 白名单（保守边界；放开 = registry 改 darwin=true）"
            ;;
        esac
      done
      if [ ! -f "$f" ]; then
        seed="$(effective_selection "$host_key" "$front")" \
          || die "当前有效选择求值失败（$host_key 输出不可求值？修好后再操作）"
        # shellcheck disable=SC2086
        local_selection_write "$host_key" $seed
        printf 'roam: 已生成 %s（种子 = 当前有效选择）\n' "$f"
      fi
      cur="$(local_selection_read "$host_key")" || die "无法读取 $f，未修改选配"
      changed=false
      # shellcheck disable=SC2086
      for new_name in $names; do
        if [ "$action" = enable ]; then
          if sel_has "$cur" "$new_name"; then
            printf 'roam: %s 已启用，跳过\n' "$new_name"
          else
            cur="$(printf '%s\n%s\n' "$cur" "$new_name")"
            changed=true
          fi
        else
          if sel_has "$cur" "$new_name"; then
            # grep -v 滤空输出时 rc=1，赋值在 set -e 下会静默中止——|| true 兜住
            cur="$(printf '%s\n' "$cur" | grep -vxF "$new_name" || true)"
            changed=true
          else
            printf 'roam: %s 未启用，无需停用\n' "$new_name"
          fi
        fi
      done
      if [ "$changed" = true ]; then
        cur="$(printf '%s\n' "$cur" | sed '/^$/d')"
        # shellcheck disable=SC2086
        local_selection_write "$host_key" $cur
        printf 'roam: 选配已更新（%s 层启用）。差异：\n' "$(printf '%s\n' "$cur" | grep -c . || true)"
        # shellcheck disable=SC2086
        for new_name in $names; do
          if [ "$action" = enable ]; then printf '  + %s\n' "$new_name"; else printf '  - %s\n' "$new_name"; fi
        done
        printf 'roam: 验证 roam check %s，生效 roam switch\n' "$host_key"
      else
        printf 'roam: 无变化\n'
      fi
      ;;
    *)
      module_usage >&2
      die "module: 未知动作：$action（init / list / enable / disable）"
      ;;
  esac
}
