{ config, pkgs, ... }:

{
  # -------------------------
  # 1. 自动垃圾回收（清理系统世代和未被引用的包）
  # -------------------------
  nix.gc = {
    automatic = true;                # 启用自动垃圾回收
    dates = "weekly";                # 执行频率，可用 "daily", "weekly", "monthly" 或具体时间如 "03:15"
    options = "--delete-older-than 2w";  # 删除超过30天的旧系统世代并回收垃圾
    # 可选：如果你想保留最近的几个版本，可以改为 "--delete-older-than 30d --keep-last 3"
  };

  # -------------------------
  # 2. 存储优化（自动将相同内容的文件硬链接，节省空间）
  # -------------------------
  nix.optimise = {
    automatic = true;                # 启用自动存储优化
    dates = [ "daily" ];            # 每天凌晨3:15执行一次优化（可根据需要调整）
  };

  # -------------------------
  # 3. 额外：自动清理用户环境的旧版本（通过 systemd 定时服务）
  # -------------------------
  # 注意：nix.gc 的 --delete-older-than 只会清理系统世代，
  # 但每个用户通过 nix-env 安装的软件也会产生世代，需要单独清理。
  # 下面创建一个系统级定时任务，以每个用户身份执行清理（或仅针对当前用户）。
  systemd.services.clean-user-generations = {
    description = "Clean old user environment generations";
    startAt = "weekly";                 # 每周运行一次，可根据需要调整
    serviceConfig = {
      Type = "oneshot";
      User = "root";                    # 以 root 运行，可以清理所有用户的环境
      ExecStart = let
        # 遍历所有有 home 目录的用户，执行 nix-env 清理
        cleanCmd = pkgs.writeShellScript "clean-user-generations" ''
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
}
