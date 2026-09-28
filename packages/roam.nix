# packages/roam.nix
#
# roam 统一 CLI 的打包层：把 packages/roam.sh 以 writeShellApplication 装为 bin/roam
# （构建期强制 bash -n + shellcheck，是本仓库脚本少有的静态检查门），再经 symlinkJoin
# 合并 packages/roam-completion.bash 为 share/bash-completion/completions/roam ——
# bash-completion（≥2.12）按 $XDG_DATA_DIRS 下的 bash-completion/completions/ 懒加载：
# standalone 侧 HM 把 ~/.nix-profile/share 注入 XDG_DATA_DIRS，NixOS 侧
# /share/bash-completion 是 pathsToLink 默认值、system sw 的 share 同样进 XDG_DATA_DIRS，
# 两侧均免额外接线。补全文件不经 writeShellApplication 的检查门，由 flake checks 的
# shellcheck-scripts 关卡覆盖（nix flake check / CI eval.yml 第三层）。
# 经 packages/cli-dev.nix 挂入四个安装点（NixOS 桌面/WSL 系统级、standalone Linux/macOS
# 用户级），同一包内 bin/ 与补全文件总是成对出现。
# 不带 runtimeInputs：nix / git / home-manager / nh 都是各安装点本就具备的环境工具，
# 拉进闭包反而会把 NixOS 专属的 nh 拖进 standalone —— 可用性由脚本按子命令自查并给出指引。
{ pkgs }:
pkgs.symlinkJoin {
  name = "roam";
  paths = [
    (pkgs.writeShellApplication {
      name = "roam";
      text = builtins.readFile ./roam.sh;
    })
    (pkgs.writeTextDir "share/bash-completion/completions/roam"
      (builtins.readFile ./roam-completion.bash))
  ];
}
