# modules/android/packages.nix
#
# Android 开发环境共享包列表（NixOS 系统级 / standalone 用户级同源）。
# JDK + Gradle + adb/fastboot + Android Studio（GUI，unfree → 只在此可选层，不进
# cli-dev 共享列表）+ 预置只读 SDK（ANDROID_HOME 由各前端接线：
# standalone → home/android-linux.nix；NixOS → ./nixos.nix）。
{ pkgs-stable, ... }:

[
  # 设备调试：adb / fastboot
  pkgs-stable.android-tools

  # 命令行构建：JDK 21 + Gradle（AGP 8.x 需 JDK 17+；项目自带 gradlew 亦可用）
  pkgs-stable.openjdk
  pkgs-stable.gradle

  # IDE（GUI，standalone 经 WSLg 显示；闭包 ~2GB）
  pkgs-stable.android-studio

  # 预置只读 SDK：share/android-sdk = ANDROID_HOME 目标，bin/sdkmanager 直通 PATH。
  # 进包列表同时保证 SDK 在 profile 闭包内有 GC 根（仅靠会话变量的文本引用不算）。
  (import ./sdk.nix { inherit pkgs-stable; })
]
