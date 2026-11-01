# modules/android/nixos.nix
#
# Android 开发档（系统级）：共享包列表 + ANDROID_HOME 接线。
# 无系统级服务；模拟器/NDK 不在预置范围（见 packages.nix / sdk.nix 头注释）。
{ pkgs, pkgs-stable, ... }:

{
  environment.systemPackages = import ./packages.nix { inherit pkgs pkgs-stable; };

  # 指向预置只读 SDK 根；项目需增量组件时用 sdkmanager 自建用户目录（见 sdk.nix）。
  environment.variables.ANDROID_HOME = "${(import ./sdk.nix { inherit pkgs-stable; })}/share/android-sdk";
}
