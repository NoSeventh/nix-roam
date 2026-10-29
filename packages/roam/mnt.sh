#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.
# kernel is initialized by core.sh.
# shellcheck disable=SC2154

mnt_usage() {
  cat <<'EOF'
用法：roam mnt [动作]（无需仓库检出目录）

  start               NixOS 注册系统级懒加载；standalone 直接启动 SSHFS
  stop                NixOS 停止懒加载及挂载；standalone 卸载 SSHFS
  status              查看挂载或懒加载状态（默认）
  -h, --help          显示本帮助

当前后端由 mnt 模块提供；SSHFS 与 FUSE 工具须在 PATH 中。
EOF
}

mnt_mount_point="${ROAM_MNT_MOUNT_POINT:-$HOME/mnt/juno}"
mnt_remote="${ROAM_MNT_REMOTE:-xuqihao@lxlogin.ihep.ac.cn:/}"
mnt_state_dir="${ROAM_MNT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nix-roam}"

mnt_require() {
  command -v "$1" >/dev/null 2>&1 \
    || die "mnt 需要 $1（请先启用 mnt 模块并执行 roam switch）"
}

mnt_is_mounted() {
  if [ "$kernel" = Linux ]; then
    # 不 stat/realpath 挂载点：status 不应触发 autofs，也不能把 autofs 当成 SSHFS。
    findmnt -rn --nocanonicalize --mountpoint "$mnt_mount_point" --types fuse.sshfs >/dev/null
  else
    mountpoint -q "$mnt_mount_point"
  fi
}

mnt_require_mount_check() {
  if [ "$kernel" = Linux ]; then mnt_require findmnt; else mnt_require mountpoint; fi
}

mnt_system_unit() {
  mnt_require systemd-escape
  systemd-escape --path "$mnt_mount_point"
}

mnt_system_require() {
  local state
  mnt_require systemctl
  state="$(systemctl --system show --property=LoadState --value "$1.automount")" || return
  [ "$state" = loaded ] || die 'mnt 系统单元未安装（请先启用 mnt 模块并执行 roam switch）'
}

mnt_start() {
  local lock_file log_file unit pid attempt rc
  mnt_require_mount_check
  if is_nixos; then
    unit="$(mnt_system_unit)" || return
    mnt_system_require "$unit" || return
    if systemctl --system is-failed --quiet "$unit.mount"; then
      sudo systemctl --system reset-failed "$unit.mount" || return
    fi
    sudo systemctl --system start "$unit.automount" || return
    mnt_status
    return
  fi
  mnt_require sshfs
  mkdir -p "$mnt_mount_point" "$mnt_state_dir" || return
  mnt_is_mounted && return 0

  mnt_require flock
  mnt_require nohup
  lock_file="$mnt_state_dir/mnt.lock"
  log_file="$mnt_state_dir/mnt.log"
  (
    exec 9>"$lock_file" || exit
    flock -w 20 9 || die '等待 mnt 启动锁超时'
    mnt_is_mounted && exit 0
    nohup sshfs -f "$mnt_remote" "$mnt_mount_point" \
      -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,BatchMode=yes,StrictHostKeyChecking=yes,ConnectTimeout=10 \
      >>"$log_file" 2>&1 </dev/null 9>&- &
    pid=$!
    for ((attempt = 0; attempt < 15; attempt++)); do
      if mnt_is_mounted; then exit 0; fi
      if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid"
        rc=$?
        printf 'roam: SSHFS 未建立挂载，请检查 %s\n' "$log_file" >&2
        [ "$rc" -ne 0 ] || rc=1
        exit "$rc"
      fi
      sleep 1
    done
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    die "SSHFS 挂载超时，请检查 $log_file"
  )
}

mnt_stop() {
  local unit
  mnt_require_mount_check
  if is_nixos; then
    unit="$(mnt_system_unit)" || return
    mnt_system_require "$unit" || return
    sudo systemctl --system stop "$unit.automount" "$unit.mount"
    return
  fi
  mnt_is_mounted || return 0
  if command -v fusermount3 >/dev/null 2>&1; then
    fusermount3 -u "$mnt_mount_point"
  else
    mnt_require fusermount
    fusermount -u "$mnt_mount_point"
  fi
}

mnt_status() {
  local unit
  mnt_require_mount_check
  if mnt_is_mounted; then
    printf '%s\n' "mounted: $mnt_mount_point"
  else
    if is_nixos; then
      unit="$(mnt_system_unit)" || return
      if systemctl --system is-failed --quiet "$unit.mount"; then
        printf 'mount failed: %s\n查看日志：journalctl -b -u %s.mount\n' "$mnt_mount_point" "$unit" >&2
        return 1
      fi
      if systemctl --system is-active --quiet "$unit.automount"; then
        printf '%s\n' "automount ready: $mnt_mount_point (not mounted)"
        return 0
      fi
    fi
    printf '%s\n' "not mounted: $mnt_mount_point"
    return 1
  fi
}

cmd_mnt() {
  local action="${1:-status}"
  [ "$#" -le 1 ] \
    || die 'roam mnt 只接受一个动作参数（start / stop / status）'
  case "$action" in
    -h | --help)
      mnt_usage
      return 0
      ;;
    start | stop | status)
      ;;
    *)
      mnt_usage >&2
      die "未知 mnt 动作：$action"
      ;;
  esac

  case "$action" in
    start) run_logged mnt-start mnt_start ;;
    stop) run_logged mnt-stop mnt_stop ;;
    status) mnt_status ;;
  esac
}
