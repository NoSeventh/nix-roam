# home/common.nix
#
# 跨平台、纯 CLI 的 Home Manager 核心配置。
# 被 home/default.nix（NixOS）与 home/standalone-{linux,darwin}.nix（非 NixOS）共同导入。
# 零 GUI 假设：NixOS / WSL / 普通 Linux / macOS 均可运行。
{ config, pkgs, inputs, lib, ... }:

let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
in
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./nixvim.nix
    ./fastfetch.nix
  ];

  # --- 1. Git ---
  programs.git = {
    enable = true;
    settings = {
      user.name = "xuqihao";
      user.email = "xuqihao@ihep.ac.cn";
    };
  };

  # --- 2. Bash ---
  # 切换入口不走别名：hms（standalone 函数）与 nrs（NixOS 别名）已于 2026-09-28 移除，
  # 由 roam 统一 CLI 的 switch 子命令替代（packages/roam.sh，四安装点共享、宿主分发、
  # 含 meta.json 用户守卫；两条替代分支均已实机验证，见 docs/VALIDATION.md）。
  # 教训存档：往本属性集注入平台条件键时必须属性集级 lib.optionalAttrs 门控，而非对
  # 字符串选项 lib.optionalString 置空串——HM 对「显式空串」与「未设置」生成的 bashrc
  # 不同（多一个空行），会平移整个闭包哈希（VALIDATION.md 判断标准一节）。
  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "eza -l --icons";
      lt = "eza -lT --icons";
      la = "eza -la --icons";
      # npm 兜底源（npmmirror 不可用时）：npmr install <pkg>
      npmr = "npm --registry=https://repo.nju.edu.cn/repository/npm/";
      # 轻量 fastfetch：ff 极简列表（无 packages/publicip 等慢模块）；ffn 无配置默认样式（带 logo）
      ff = "fastfetch --structure 'title:os:kernel:uptime:shell:cpu:memory:disk'";
      ffn = "fastfetch -c none";
      shh = "ssh xuqihao@lxlogin.ihep.ac.cn";
      shhfs = "sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 xuqihao@lxlogin.ihep.ac.cn:/ ~/mnt/juno/";
      afs = "cd ~/mnt/juno/afs/ihep.ac.cn/users/x/xuqihao";
      scratchfs = "cd ~/mnt/juno/scratchfs/juno/xuqihao";
      junofs = "cd ~/mnt/juno/junofs/users/xuqihao";
      workfs = "cd ~/mnt/juno/workfs2/juno/xuqihao";
      root = "root -l";
    } // lib.optionalAttrs isLinux {
      # Linux 专用：macOS 上无 distrobox，不注入避免误用
      archbox = "distrobox enter archbox";
      susebox = "distrobox enter susebox";
      fedorabox = "distrobox enter fedorabox";
      kalibox = "distrobox enter kalibox";
      debianbox = "distrobox enter debianbox";
    };
  };

  # --- 3. Starship 提示符 ---
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
    };
    presets = [ "gruvbox-rainbow" ];
  };

  # --- 4. Helix 编辑器 ---
  programs.helix = {
    enable = true;
    settings = {
      theme = "base16_transparent";
    };
  };

  # --- 5. SSH ---
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "juno" = {
        hostname = "lxlogin.ihep.ac.cn";
        user = "xuqihao";
        port = 22;
      };
    };
  };

  # --- 6. npm ---
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    # 中国大陆加速：默认走 npmmirror（npm / npx 通用）。
    # 环境变量优先级高于项目级 .npmrc；个别项目要用自己的 registry 时：
    #   npm i --registry=<url>   或   unset NPM_CONFIG_REGISTRY
    NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/go/bin"
    "${config.home.homeDirectory}/.bun/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
  ];

  # --- 7. 便携 dotfiles（GUI 终端配置不在此） ---
  home.file = {
    ".npm-global" = {
      source = pkgs.emptyDirectory;
      recursive = true;
    };
    ".config/btop" = {
      source = ../dotfiles/.config/btop;
      recursive = true;
    };
  };
}
