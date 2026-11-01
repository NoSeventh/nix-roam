# modules/android/sdk.nix
#
# 预置 Android SDK（androidenv 组装，只读 store 路径）+ sdkmanager 直通 PATH。
# 组合刻意对冲不同项目各自锁定的 AGP 组件版本：三代平台 + 三代 build-tools +
# platform-tools + cmdline-tools；许可证在 flake.nix 的 nixpkgsConfig 经
# android_sdk.accept_license 预接受。
# 刻意不含模拟器 / NDK / 系统镜像（体积与 WSL 嵌套虚拟化考虑；需要时项目另行扩展）。
# 扩展姿势：store 只读，增量组件须自建用户 SDK 目录，如
#   sdkmanager --sdk_root=$HOME/Android/Sdk "platforms;android-34"
# 再让项目 / ANDROID_HOME 指向该目录；预置组合内的组件则无需任何额外安装。
{ pkgs-stable, ... }:

let
  composed = pkgs-stable.androidenv.composeAndroidPackages {
    platformVersions = [ "35" "36" "37.0" ];
    buildToolsVersions = [ "35.0.0" "36.0.0" "37.0.0" ];
    includeEmulator = false;
    includeNDK = false;
    includeSystemImages = false;
  };
  sdkRoot = "${composed.androidsdk}/libexec/android-sdk";
in
pkgs-stable.runCommand "android-sdk-env" { } ''
  set -e
  mkdir -p $out/bin $out/share
  # ANDROID_HOME 目标（各前端接线见 packages.nix 头注释）
  ln -s ${sdkRoot} $out/share/android-sdk
  # cmdline-tools 版本随频道漂移，按 glob 定位单实例（多于一个则显式失败）
  sdkmanager=( "${sdkRoot}"/cmdline-tools/*/bin/sdkmanager )
  [ "''${#sdkmanager[@]}" -eq 1 ] || { echo "android-sdk-env: cmdline-tools 意外数量 ''${#sdkmanager[@]}" >&2; exit 1; }
  ln -s "''${sdkmanager[0]}" $out/bin/sdkmanager
''
