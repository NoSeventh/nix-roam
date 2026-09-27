# packages/roam.nix
#
# roam 统一 CLI 的打包层：把 packages/roam.sh 以 writeShellApplication 装为 bin/roam
# （构建期强制 bash -n + shellcheck，是本仓库脚本少有的静态检查门）。
# 经 packages/cli-dev.nix 挂入四个安装点（NixOS 桌面/WSL 系统级、standalone Linux/macOS 用户级）。
# 不带 runtimeInputs：nix / git / home-manager / nh 都是各安装点本就具备的环境工具，
# 拉进闭包反而会把 NixOS 专属的 nh 拖进 standalone —— 可用性由脚本按子命令自查并给出指引。
{ pkgs }:
pkgs.writeShellApplication {
  name = "roam";
  text = builtins.readFile ./roam.sh;
}
