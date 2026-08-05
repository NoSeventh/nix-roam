# 中国大陆网络适配（Nix 侧共享配置，单一事实源）
# 被 modules/fix-network.nix（NixOS daemon）与 home/standalone-{linux,darwin}.nix（用户级）共同 import。
# 只放三端都安全生效的设置；daemon 级设置（download-buffer-size / auto-optimise-store）留在 fix-network.nix。
{ lib, ... }:

{
  nix.settings = {
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
