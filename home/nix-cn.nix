# 中国大陆网络适配（Nix 侧共享配置，单一事实源）
# 被 modules/fix-network.nix（NixOS daemon）与 home/standalone-{linux,darwin}.nix（用户级）共同 import。
# 只放三端都安全生效的设置；daemon 级设置（download-buffer-size / auto-optimise-store）留在 fix-network.nix。
{ lib, pkgs, ... }:

{
  # HM 断言：生成 nix.conf 时必须指定 nix.package
  nix.package = pkgs.nix;

  nix.settings = {
    # bootstrap/linux.sh 曾把这一行写进用户级 nix.conf；HM 接管后需要保留。
    # NixOS 上 configuration.nix 也设置同值，mkForce 避免列表合并产生重复项。
    experimental-features = lib.mkForce [
      "nix-command"
      "flakes"
    ];

    # 优先使用国内镜像站
    substituters = lib.mkForce [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];

    connect-timeout = 5;
    fallback = true;
  };
}
