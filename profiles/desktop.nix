# 桌面基座 profile：系统基座 + 会话栈 + 桌面核心（开源桌面应用，尾部并共享 CLI 列表）。
# 可选层（browsers/dev/media/office/proxy/gaming/agents/mnt/virtualization/flatpak/
# desktop-managers）自 2026-10-11 起不再罗列在本文件——经 lib/selection.nix 按主机
# 选择：入库默认集写在 hosts/<hostname>/default.nix，机器本地 local.<hostname>.json
# （gitignored，roam module 维护）在 path: 求值视图下整体替换之。原 desktop-lite
# 组合 = 某主机 default 里少列几层，不再需要单独的 profile 文件。
# 主机特有设置（boot/kernel/hostname/电源/用户组）属 hosts/<hostname>/default.nix。
{ ... }:

{
  imports = [
    ./nixos-base.nix
    ../modules/desktop/session.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/locale-zh.nix
    ../modules/desktop/core.nix
  ];
}
