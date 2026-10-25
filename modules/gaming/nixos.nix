# modules/gaming/nixos.nix
#
# 游戏兼容档：为 Wine 等开源程序提供 32 位图形支持；
# virtualization.nix 因 Wine 另有一份同值声明（bool 同值多定义合并无冲突）。
{ ... }:

{
  # 32 位图形支持。
  hardware.graphics.enable32Bit = true;
}
