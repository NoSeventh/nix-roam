# Shared NixOS foundation for desktop and WSL hosts.
{ pkgs-stable, username, stateVersion, vars, ... }:

{
  imports = [
    ../modules/fix-network.nix
    ./locale.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # 时区是机器级参数，经 hosts/<hostname>/variables.nix → specialArgs.vars 注入
  time.timeZone = vars.timeZone;

  # --- 0. nh：NixOS 重建前端（nrs 别名的后端） ---
  #     刻意不设 programs.nh.flake：那会硬编码 checkout 路径，nrs 改为按 cwd 传
  #     位置参数（仓库根运行契约不变）；也不启用 nh clean —— GC 仍走 bootstrap/gc.sh。
  programs.nh.enable = true;

  # --- 1. NixOS development runtimes (desktop and WSL) ---
  # Standalone hosts use native/project runtime management instead.
  environment.systemPackages = with pkgs-stable; [
    nodejs
    pnpm
    R
    # The C++ ROOT application comes from packages/cli-dev.nix.
    # Keep Python and ROOT bindings in the same package set / Python ABI.
    ((python3.withPackages (ps: with ps; [
      pip
      jupyter
      pyyaml
      pandas
      polars
      numpy
      scipy
      sympy
      matplotlib
      requests
      pytest
      root # PyROOT bindings from the Python package set.
      uproot
      rpy2
      torch
    ])).override {
      # rpy2 needs R at runtime, not only in its build environment.
      makeWrapperArgs = [ "--set" "R_HOME" "${pkgs-stable.R}/lib/R" ];
    })
  ];

  users.users.${username} = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = [ "wheel" ];
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
    # pnpm-10.29.2 仅桌面闭包引用（GNOME 模块链，flatpak-linyaps.nix）；
    # WSL 不引用但删掉无效也无益——nixpkgs.config 跨模块浅合并，
    # 拆到 profiles/desktop.nix 会遮蔽 electron 条目，只能在共享处单点声明。
    "pnpm-10.29.2"
  ];

  # 单点定义在 flake.nix 顶层 let，经 specialArgs 注入；被采纳的老主机在 hosts/<hostname>/ 用 mkForce 保留原值
  system.stateVersion = stateVersion;
}
