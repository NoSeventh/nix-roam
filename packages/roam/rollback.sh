#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# shellcheck disable=SC2034
cmd_rollback() {
  local want='' list=false yes=false i target_idx total seg_cur seg_tgt log rc answer n d cur_link
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --list) list=true ;;
      -y | --yes) yes=true ;;
      -*) die "rollback: 未知选项：$1" ;;
      *[!0-9]*) die "rollback: 世代号必须是数字：$1（roam rollback --list 查看）" ;;
      *) want="$1" ;;
    esac
    shift
  done
  if is_nixos; then
    if [ "$list" = true ]; then
      # 非 root 也能列（nix-env 需 profile 锁，见 system_generation_ids 注释）；
      # 日期取链接自身 mtime（GNU stat 不跟随符号链接，与 nix-env 同源），
      # 当前世代以 system 链接目标为准。
      cur_link="$(readlink /nix/var/nix/profiles/system 2>/dev/null)"
      system_generation_ids | while read -r n; do
        d="$(stat -c '%y' "/nix/var/nix/profiles/system-${n}-link" 2>/dev/null)"
        d="${d%%.*}"
        if [ "system-${n}-link" = "${cur_link##*/}" ]; then
          printf 'id %-4s %s  （当前）\n' "$n" "$d"
        else
          printf 'id %-4s %s\n' "$n" "$d"
        fi
      done
      return 0
    fi
    printf 'roam: NixOS 回滚走 nixos-rebuild（nh 无回滚入口；sudo 自行提权）\n'
    if [ -n "$want" ]; then
      run_logged rollback sudo nixos-rebuild switch --switch-generation "$want"
      return $?
    fi
    run_logged rollback sudo nixos-rebuild switch --rollback
    return $?
  fi
  load_hm_generations || die '未找到 home-manager 世代（本机尚未激活过？）'
  total="${#GEN_PATHS[@]}"
  if [ "$list" = true ]; then
    i=0
    while [ "$i" -lt "$total" ]; do
      seg_cur=''
      if [ "$i" = "$GEN_CURRENT" ]; then
        seg_cur='（当前）'
      fi
      printf 'id %-4s %s  %-8s %s\n' "${GEN_IDS[$i]}" "${GEN_DATES[$i]}" "$seg_cur" "${GEN_PATHS[$i]##*/}"
      i=$((i + 1))
    done
    return 0
  fi
  target_idx=''
  if [ -n "$want" ]; then
    i=0
    while [ "$i" -lt "$total" ]; do
      if [ "${GEN_IDS[$i]}" = "$want" ]; then
        target_idx=$i
        break
      fi
      i=$((i + 1))
    done
    [ -n "$target_idx" ] || die "没有世代 id ${want}（roam rollback --list 查看）"
    if [ "$target_idx" = "$GEN_CURRENT" ]; then
      die "id ${want} 已是当前世代"
    fi
  else
    # 缺省回滚目标 = 当前世代之后第一个「内容不同」的世代：rollback 的 activate 会把
    # 旧内容登记为新世代号，直接取下一条会踩回刚离开的内容（同 store 路径）。
    target_idx=$((GEN_CURRENT + 1))
    while [ "$target_idx" -lt "$total" ] && [ "${GEN_PATHS[$target_idx]}" = "${GEN_PATHS[$GEN_CURRENT]}" ]; do
      target_idx=$((target_idx + 1))
    done
    [ "$target_idx" -lt "$total" ] || die '当前已是最早世代，没有更早的可回滚'
  fi
  seg_cur="${GEN_PATHS[$GEN_CURRENT]##*/}（id ${GEN_IDS[$GEN_CURRENT]}）"
  seg_tgt="${GEN_PATHS[$target_idx]##*/}（id ${GEN_IDS[$target_idx]}，${GEN_DATES[$target_idx]}）"
  printf '回滚：%s\n  → %s\n' "$seg_cur" "$seg_tgt"
  if [ "$yes" = false ]; then
    printf '确认回滚？[y/N] '
    read -r answer || answer=''
    case "$answer" in
      y | Y | yes | YES) : ;;
      *)
        printf 'roam: 已取消\n'
        return 0
        ;;
    esac
  fi
  log="$(new_log rollback)"
  {
    printf 'roam rollback\n'
    printf 'date : %s\n' "$(date '+%F %T')"
    printf 'from : %s\n' "$seg_cur"
    printf 'to   : %s\n' "$seg_tgt"
    printf -- '----------------------------------------\n'
  } >"$log"
  set +e
  "${GEN_PATHS[$target_idx]}/activate" 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'roam: 已回滚到 id %s（roam status 查看；roam switch 回到检出）\n' "${GEN_IDS[$target_idx]}"
  else
    printf 'roam: 回滚失败（rc=%s），日志 %s\n' "$rc" "$log" >&2
  fi
  return "$rc"
}
