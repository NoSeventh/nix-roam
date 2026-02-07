{ config, pkgs, lib, ... }:

{
  nix.settings = {
    # 优先使用国内镜像站
    substituters = lib.mkForce [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];

    # 增大下载缓存，防止大文件下载中断 (500MB)
    download-buffer-size = 524288000;
    
    connect-timeout = 5;
    fallback = true;
    
     # 自动优化存储，节省空间
     auto-optimise-store = true;
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
