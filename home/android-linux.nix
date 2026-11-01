# home/android-linux.nix
#
# standalone 前端的 android 档环境接线：ANDROID_HOME 指向预置只读 SDK。
# 层的 home.nix 契约是纯包列表（standalone-linux.nix 直接拼 home.packages），
# 会话变量只能经模块挂载——由入口按 sel.modules 门控 import（mnt 层同款机制，
# 见 standalone-linux.nix 的 imports 门控注释）。
{ pkgs-stable, ... }:

{
  home.sessionVariables.ANDROID_HOME = "${(import ../modules/android/sdk.nix { inherit pkgs-stable; })}/share/android-sdk";
}
