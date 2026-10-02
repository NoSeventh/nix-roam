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

  # --- 0. nh：重建前端（roam switch 双侧后端：NixOS → nh os、standalone → nh home） ---
  #     包自 2026-09-28 起由 packages/cli-dev.nix 单源提供（四个安装点都有），此处不再
  #     设 programs.nh —— 该模块除装包外无额外作用，且我们本就不设 programs.nh.flake
  #     （那会硬编码 checkout 路径，roam switch 按 cwd 传位置参数），也不启用
  #     nh clean（GC 仍走 roam gc）。

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

  # --- 2. Nix 维护自动化（自动 GC / 存储优化；2026-09-26 自 modules/desktop/automation.nix 下沉，
  #     desktop 与 WSL 共享 —— WSL 虚拟磁盘只增不减，自动回收尤其重要）---
  nix.gc = {
    automatic = true;                # 启用自动垃圾回收
    dates = "weekly";                # 执行频率，可用 "daily", "weekly", "monthly" 或具体时间如 "03:15"
    options = "--delete-older-than 2w";  # 删除超过 2 周的旧系统世代并回收垃圾
    # 可选：如果你想保留最近的几个版本，可以改为 "--delete-older-than 30d --keep-last 3"
  };

  nix.optimise = {
    automatic = true;                # 启用自动存储优化
    dates = [ "daily" ];             # 每日运行一次优化（可根据需要调整）
  };

  # nix.gc 的 --delete-older-than 只清理系统世代；各用户经 nix-env 安装的软件另产生世代，
  # 由下面的系统级定时任务遍历有 .nix-profile 的用户、以其身份执行清理。
  systemd.services.clean-user-generations = {
    description = "Clean old user environment generations";
    startAt = "weekly";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = let
        cleanCmd = pkgs-stable.writeShellScript "clean-user-generations" ''
          for user_home in /home/*; do
            user=$(basename "$user_home")
            # 跳过没有 .nix-profile 的用户
            if [ -e "/home/$user/.nix-profile" ]; then
              echo "Cleaning generations for user: $user"
              sudo -u "$user" nix-env --delete-generations old || true
            fi
          done
          # 也可以清理 root 自己的 nix-env 世代（如果 root 也用过 nix-env）
          if [ -e "/root/.nix-profile" ]; then
            echo "Cleaning generations for root"
            nix-env --delete-generations old || true
          fi
        '';
      in cleanCmd;
    };
  };

  nixpkgs.config.allowUnfree = true;
  # unstable 实例的 insecure 允许清单（2026-10-02 复核，两条仍均被桌面闭包引用）：
  # - electron-40.10.5：unstable 的 electron_40 仍是该版本（探针 electron/electron_41 =
  #   43.6.0/41.10.6 会误判此条已死——移除后桌面求值即拒 40.10.5，实测恢复）。
  # - pnpm-10.29.2：GNOME 模块链（desktop-managers.nix）仍引用，unstable pkgs.pnpm =
  #   12.3.4 同样不能作为「无引用者」的证据（移除后桌面求值即拒，实测恢复）。
  # 教训：顶点属性探针覆盖不了版本化/被钉住的引用面，条目存亡以受影响输出的求值为准。
  # 注意 nixpkgs.config 跨模块浅合并——即使条目只被桌面闭包引用，也不能拆去
  # profiles/desktop.nix（会在该处形成遮蔽），只能在共享处单点声明。
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
    "pnpm-10.29.2"
  ];

  # 单点定义在 flake.nix 顶层 let，经 specialArgs 注入；被采纳的老主机在 hosts/<hostname>/ 用 mkForce 保留原值
  system.stateVersion = stateVersion;
}
