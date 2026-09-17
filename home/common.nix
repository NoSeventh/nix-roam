# home/common.nix
#
# 跨平台、纯 CLI 的 Home Manager 核心配置。
# 被 home/default.nix（NixOS）与 home/standalone-{linux,darwin}.nix（非 NixOS）共同导入。
# 零 GUI 假设：NixOS / WSL / 普通 Linux / macOS 均可运行。
{ config, pkgs, inputs, lib, isStandalone, username, ... }:

let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  # standalone 输出名按求值目标架构派生：Linux 双架构显式输出 + macOS。
  # hms 别名据此自动选 target，aarch64 机器上裸敲 hms 同样正确（→ .#xuqihao-aarch64）。
  hmTarget =
    if isLinux
    then (if pkgs.stdenv.hostPlatform.isAarch64 then "${username}-aarch64" else username)
    else "${username}-darwin";
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
  # 注意 hms 的注入方式：initExtra 必须用属性集级 lib.optionalAttrs 门控（而非字符串级
  # lib.optionalString 置空串）——HM 对「显式设置为空串」和「未设置」生成的 bashrc 不同
  # （前者会多出一个空行），会无谓改变 NixOS 侧整个系统闭包的派生哈希。
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
      # Linux 专用：macOS 上无 nixos-rebuild / distrobox，不注入避免误用
      # nrs 需在仓库根目录下运行：--flake . 按 cwd 解析，attr 自动补 #$(hostname)
      nrs = "sudo nixos-rebuild switch --flake .";
      archbox = "distrobox enter archbox";
      susebox = "distrobox enter susebox";
      fedorabox = "distrobox enter fedorabox";
      kalibox = "distrobox enter kalibox";
      debianbox = "distrobox enter debianbox";
    };
  } // lib.optionalAttrs isStandalone {
    # hms 用 shell 函数而非别名：需要 if/fi 校验逻辑，嵌在别名字符串里可读性差。
    # bash 模块没有 functions 选项（那是 zsh 的），交互式函数走 initExtra。
    # 仅 standalone 模式注入：NixOS（桌面/WSL）走集成 HM + nrs，没有 standalone profile 可切
    # （必须属性集级门控，见上方注释）。
    # target 由 meta.json 单点定义的 username 派生（Linux .#<user>，macOS .#<user>-darwin，避免误激活另一平台）；
    # 先校验当前登录用户，不符时明确拒绝，而不是把配置写进别人的 HOME。
    initExtra = ''
      hms() {
        if [ "$(id -un)" = "${username}" ]; then
          home-manager switch --flake .#${hmTarget}
        else
          echo "hms: 当前用户是 $(id -un)，不是 ${username}；拒绝切换（本地用户名在 meta.json 单点定义）"
          false
        fi
      }
    '';
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
