#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034,SC2154  # kernel is initialized by core.sh
# 列出 flake.lock 顶层输入供选择（菜单走 stderr，选定的输入名走 stdout，空输出=全部）。
# EOF / 无 jq / 无 flake.lock 一律回落「全部」（默认全选）；无效输入则中止。
choose_inputs() {
  local input_names reply tok name nm n idx picked='' all_names='' rev date
  command -v jq >/dev/null 2>&1 || { printf 'roam: 无 jq，跳过选择，按全部输入更新\n' >&2; return 0; }
  [ -f flake.lock ] || { printf 'roam: 无 flake.lock，按全部输入更新\n' >&2; return 0; }
  input_names="$(jq -r '
    .nodes as $nodes | $nodes.root.inputs | to_entries[] |
    .key as $k | .value as $v |
    (if ($v|type)=="string" then (try ($nodes[$v].locked.rev // "-") catch "-") else "-" end) as $rev |
    (if ($v|type)=="string" then (try ($nodes[$v].locked.lastModified | localtime | strftime("%Y-%m-%d")) catch "-") else "-" end) as $date |
    "\($k)\t\(if $rev=="-" then "-" else $rev[0:7] end)\t\($date)"
  ' flake.lock)" || return 0
  printf 'flake 输入（flake.lock 当前锁定）:\n' >&2
  idx=0
  while IFS=$'\t' read -r name rev date; do
    [ -n "$name" ] || continue
    idx=$((idx + 1))
    printf '  %d) %-16s %s  %s\n' "$idx" "$name" "$rev" "$date" >&2
    all_names="$all_names $name"
  done <<EOF
$input_names
EOF
  printf '选择要更新的输入：回车=全部；或输入编号/名称（空格或逗号分隔，如 1 3 / nixpkgs nixvim）: ' >&2
  read -r reply || return 0
  [ -n "$reply" ] || return 0
  # 用户回复里逗号与空格统一当分隔符；输入名本身不含空格（flake 输入名为标识符）
  # shellcheck disable=SC2086
  for tok in $(printf '%s' "$reply" | tr ',' ' '); do
    name=''
    case "$tok" in
      '' | *[!0-9]*) name="$tok" ;;
      *)
        # 纯数字：按编号取名字
        n=0
        # shellcheck disable=SC2086
        for nm in $all_names; do
          n=$((n + 1))
          if [ "$n" = "$tok" ]; then
            name="$nm"
            break
          fi
        done
        ;;
    esac
    if [ -z "$name" ]; then
      die "无法识别的选择：$tok"
    fi
    case " $all_names " in
      *" $name "*) : ;;
      *) die "未知输入：$name（可用：${all_names# }）" ;;
    esac
    case " $picked " in
      *" $name "*) : ;;
      *) picked="$picked $name" ;;
    esac
  done
  printf '%s' "${picked# }"
}

cmd_update() {
  local all=false names='' sel
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -a | --all) all=true ;;
      -*) die "update: 未知选项：$1" ;;
      *) names="$names $1" ;;
    esac
    shift
  done
  names="${names# }"
  if [ "$all" = true ] && [ -n "$names" ]; then
    die "update: --all 与输入名不能同时指定"
  fi
  repo_check
  if [ "$all" = false ] && [ -z "$names" ]; then
    sel="$(choose_inputs)"
    names="$sel"
  fi
  if [ -n "$names" ]; then
    printf 'roam update: 更新输入：%s\n' "$names"
    # 输入名经 flake.lock 白名单或用户显式给出，不含空格与通配
    # shellcheck disable=SC2086
    nix flake update $names
  else
    printf 'roam update: 更新全部输入\n'
    nix flake update
  fi
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --stat -- flake.lock || true
  fi
  printf 'roam: 请 review 并提交 flake.lock，再以 roam check / roam switch 验证受影响目标（nix-channel --update 不会更新 flake 依赖）\n'
}

# --- flake：查看 flake.lock 锁定的输入版本 ---
# jq 读取结构化字段，不依赖 lock 的缩进或字段顺序；保留节点映射供展示。
read_flake_lock() {
  require_jq
  LOCK_NAMES=()
  LOCK_REVS=()
  LOCK_EPOCHS=()
  LOCK_REFS=()
  LOCK_SRCS=()
  ROOT_KEYS=()
  ROOT_NODES=()
  local rows kind name rev epoch ref src
  rows="$(jq -ser 'if length == 1 then .[0] else error("expected one JSON document") end |
    .nodes as $nodes | .root as $root |
    if (.version == 7) and ($nodes | type == "object") and
       ($root | type == "string") and
       ($nodes[$root].inputs | type == "object" and length > 0)
    then
      ($nodes | to_entries[] | select(.value.locked != null) |
        .value.original as $o |
        ["node", .key, (.value.locked.rev // "-"),
         (.value.locked.lastModified // "-"), ($o.ref // "-"),
         (if $o.owner != null and $o.repo != null
          then "\($o.owner)/\($o.repo)" else ($o.url // "-") end)] | @tsv),
      ($nodes[$root].inputs | to_entries[] |
        if (.value | type) == "string" then ["root", .key, .value] | @tsv
        else error("root follows input is unsupported") end)
    else error("invalid flake lock") end
  ' flake.lock)" || return 1
  while IFS=$'\t' read -r kind name rev epoch ref src; do
    case "$kind" in
      node)
        LOCK_NAMES+=("$name")
        LOCK_REVS+=("$rev")
        LOCK_EPOCHS+=("$epoch")
        LOCK_REFS+=("$ref")
        LOCK_SRCS+=("$src")
        ;;
      root) ROOT_KEYS+=("$name"); ROOT_NODES+=("$rev") ;;
    esac
  done <<EOF
$rows
EOF
  [ "${#ROOT_KEYS[@]}" -gt 0 ]
}

# epoch → UTC YYYY-MM-DD：GNU date（-d @epoch）与 BSD date（-r epoch）双语法回落
# （doctor 对世代日期回避运算是因为那只做字符串比较；这里必须转换数值时间戳）。
# 两种语法都不可用（异常平台）时打印 '-'，不视为错误。
lock_date() {
  local d=''
  d="$(date -u -d "@$1" +%F 2>/dev/null)" || d=''
  if [ -z "$d" ]; then
    d="$(date -u -r "$1" +%F 2>/dev/null)" || d=''
  fi
  printf '%s' "${d:--}"
}

cmd_flake() {
  local all=false j=0 i=0 node idx rev date ref src
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -a | --all) all=true ;;
      -*) die "flake: 未知选项：$1" ;;
      *) die "flake: 无位置参数：$1（查看锁定版本用 roam flake，更新用 roam update）" ;;
    esac
    shift
  done
  repo_check
  [ -f flake.lock ] || die '当前检出缺 flake.lock（先 nix flake lock / roam update 生成）'
  read_flake_lock || die 'flake.lock 解析失败：未识别出 root 直接输入（lock 格式变化？请反馈）'
  # 节点名 → LOCK_* 下标（线性查找；节点数 ~15，无须散列）
  lock_index() {
    local k=0
    while [ "$k" -lt "${#LOCK_NAMES[@]}" ]; do
      if [ "${LOCK_NAMES[$k]}" = "$1" ]; then
        printf '%s' "$k"
        return 0
      fi
      k=$((k + 1))
    done
    return 1
  }
  printf 'flake 输入（flake.lock 锁定；roam update 更新；--all 含传递输入）:\n'
  while [ "$j" -lt "${#ROOT_KEYS[@]}" ]; do
    node="${ROOT_NODES[$j]}"
    if idx="$(lock_index "$node")"; then
      rev="${LOCK_REVS[$idx]}"
      rev="${rev:0:7}"
      date="$(lock_date "${LOCK_EPOCHS[$idx]}")"
      ref="${LOCK_REFS[$idx]}"
      src="${LOCK_SRCS[$idx]}"
      printf '  %-22s %-7s  %-10s  %-15s %s\n' \
        "${ROOT_KEYS[$j]}" "${rev:--}" "$date" "${ref:--}" "${src:--}"
    else
      printf '  %-22s （锁定节点 %s 未解析——lock 结构异常）\n' "${ROOT_KEYS[$j]}" "$node"
    fi
    j=$((j + 1))
  done
  if [ "$all" = true ]; then
    printf '传递输入（上游 flake 自带锁定，非本仓库声明；节点名带版本后缀）:\n'
    while [ "$i" -lt "${#LOCK_NAMES[@]}" ]; do
      node="${LOCK_NAMES[$i]}"
      case " ${ROOT_NODES[*]} " in
        *" $node "*) ;;
        *)
          rev="${LOCK_REVS[$i]}"
          rev="${rev:0:7}"
          date="$(lock_date "${LOCK_EPOCHS[$i]}")"
          ref="${LOCK_REFS[$i]}"
          src="${LOCK_SRCS[$i]}"
          printf '  %-22s %-7s  %-10s  %-15s %s\n' \
            "$node" "${rev:--}" "$date" "${ref:--}" "${src:--}"
          ;;
      esac
      i=$((i + 1))
    done
  fi
}
