# home/common.nix
#
# 跨平台、纯 CLI 的 Home Manager 核心配置。
# 被 home/default.nix（NixOS）与 home/standalone.nix（非 NixOS）共同导入。
# 零 GUI 假设：NixOS / WSL / 普通 Linux / macOS 均可运行。
{ config, pkgs, pkgs-stable, inputs, ... }:

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
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.bun/bin"
    '';
    shellAliases = {
      ll = "eza -l --icons";
      lt = "eza -lT --icons";
      la = "eza -la --icons";
      nrs = "sudo nixos-rebuild switch";
      nrrs = "sudo nix-channel --update && sudo nixos-rebuild switch";
      shh = "ssh xuqihao@lxlogin.ihep.ac.cn";
      shhfs = "sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 xuqihao@lxlogin.ihep.ac.cn:/ ~/mnt/juno/";
      afs = "cd ~/mnt/juno/afs/ihep.ac.cn/users/x/xuqihao";
      scratchfs = "cd ~/mnt/juno/scratchfs/juno/xuqihao";
      junofs = "cd ~/mnt/juno/junofs/users/xuqihao";
      workfs = "cd ~/mnt/juno/workfs2/juno/xuqihao";
      archbox = "distrobox enter archbox";
      susebox = "distrobox enter susebox";
      fedorabox = "distrobox enter fedorabox";
      kalibox = "distrobox enter kalibox";
      debianbox = "distrobox enter debianbox";
      root = "root -l";
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

  # --- 6. 便携 dotfiles（GUI 终端配置不在此） ---
  home.file = {
    ".config/btop" = {
      source = ../dotfiles/.config/btop;
      recursive = true;
    };
  };
}
