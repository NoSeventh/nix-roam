# 中国大陆网络适配（Nix 侧共享配置）
# 被 modules/fix-network.nix（NixOS daemon）与 home/standalone-{linux,darwin}.nix（用户级）共同 import。
# 只放各入口都安全生效的设置；daemon 级设置（download-buffer-size / auto-optimise-store）留在 fix-network.nix。
# substituters 列表本体在仓库根 meta.json（"substituters" 字段，空格分隔）——
# bootstrap/{linux,darwin,nixos}.sh 在 Nix 安装前用 sed 读同一字段，改动只改 meta.json 一处。
{ lib, pkgs, ... }:

let
  meta = builtins.fromJSON (builtins.readFile ../meta.json);
in
{
  # HM 断言：生成 nix.conf 时必须指定 nix.package
  nix.package = pkgs.nix;

  nix.settings = {
    # bootstrap/linux.sh 曾把这一行写进用户级 nix.conf；HM 接管后需要保留。
    # NixOS 上 profiles/nixos-base.nix 也设置同值，mkForce 避免列表合并产生重复项。
    experimental-features = lib.mkForce [
      "nix-command"
      "flakes"
    ];

    # 优先使用国内镜像站（均收录于 CERNET 联合镜像站 help.mirrors.cernet.edu.cn）
    # 2026-08 实测延迟：NJU ~106ms < TUNA ~153ms < USTC ~155ms < SJTU ~435ms
    # 末位补 nix-community.cachix.org：官方 Hydra 常规任务不构建 hydraPlatforms = [ ] 的路径
    # （2026-09-24 实例：rainbow-delimiters-nvim 的插件产物与 gitlab fetchgit 源码在官方缓存
    # 与国内镜像全 404，缺了它只能现场翻 gitlab。2026-09-27 复测该路径官方缓存已覆盖、
    # 许可元数据已改回 Apache-2.0，此项现为保险——lock 更新换出新路径时同类缺口仍可能复发）。
    # 公钥不在这里声明 —— 用户级 nix.conf 里的 trusted-public-keys 对非受信用户是受限设置，
    # 会触发 "ignoring the client-specified setting" 警告；NixOS 侧见 modules/fix-network.nix，
    # standalone 侧由 bootstrap 写入 daemon 的 nix.custom.conf。
    # 列表本体在 meta.json（单源），本文件与 bootstrap/{linux,darwin,nixos}.sh 同读一份。
    substituters = lib.mkForce (lib.splitString " " meta.substituters);

    connect-timeout = 5;
    fallback = true;
  };
}
