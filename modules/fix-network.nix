{ ... }:

{
  imports = [ ../home/nix-cn.nix ];

  nix.settings = {
    # 增大下载缓存，防止大文件下载中断 (500MB)
    download-buffer-size = 524288000;

    # 自动优化存储，节省空间
    auto-optimise-store = true;

    # cachix 社区缓存公钥，配合 home/nix-cn.nix 里的 substituter 使用
    # （官方 Hydra 不构建 unfree 包，如 vimPlugins.rainbow-delimiters-nvim 的源码）。
    # 只写在 NixOS daemon 侧：用户级 nix.conf 的 trusted-public-keys 是非受信用户的受限设置，
    # standalone 侧改由 bootstrap 写进 /etc/nix/nix.custom.conf（多用户）或用户 nix.conf（单用户）。
    # 列表设置在 NixOS 模块里按 listOf 合并，与默认的 cache.nixos.org-1 并存，不会顶掉官方 key。
    # 该公钥另有 3 处副本：bootstrap/{linux,darwin,nixos}.sh，改动需同步。
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };

#   nix.extraOptions = ''
#     !include /etc/nix/github-access-tokens
#   '';

  environment.variables = {
    NIXPKGS_ALLOW_UNFREE = "1";
#    GOPROXY = "https://goproxy.cn,direct";
  };

#  systemd.services.nix-daemon.environment = {
#    GOPROXY = "https://goproxy.cn,direct";
#  };
}
