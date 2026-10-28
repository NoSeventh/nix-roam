#!/usr/bin/env bash
# Sourced by packages/roam.sh; globals are shared across command files.

mnt_usage() {
  cat <<'EOF'
用法：roam mnt [动作]（无需仓库检出目录）

  start               启动 IHEP Juno SSHFS 挂载
  stop                停止 IHEP Juno SSHFS 挂载
  status              查看挂载状态（默认）
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
  mountpoint -q "$mnt_mount_point"
}

mnt_start() {
  local lock_file log_file
  mnt_require mountpoint
  mnt_require sshfs
  mkdir -p "$mnt_mount_point" "$mnt_state_dir"

  if [ -S "${XDG_RUNTIME_DIR:-}/bus" ] && command -v systemctl >/dev/null 2>&1 &&
    systemctl --user start sshfs-remote.service >/dev/null 2>&1; then
    return 0
  fi
  mnt_is_mounted && return 0

  mnt_require flock
  mnt_require nohup
  lock_file="$mnt_state_dir/mnt.lock"
  log_file="$mnt_state_dir/mnt.log"
  (
    exec 9>"$lock_file"
    flock -n 9 || exit 0
    mnt_is_mounted && exit 0
    nohup sshfs -f "$mnt_remote" "$mnt_mount_point" \
      -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user \
      >>"$log_file" 2>&1 </dev/null &
    sleep 1
  )
}

mnt_stop() {
  mnt_require mountpoint
  if [ -S "${XDG_RUNTIME_DIR:-}/bus" ] && command -v systemctl >/dev/null 2>&1 &&
    systemctl --user stop sshfs-remote.service >/dev/null 2>&1; then
    return 0
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
  mnt_require mountpoint
  if mnt_is_mounted; then
    printf '%s\n' "mounted: $mnt_mount_point"
  else
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
