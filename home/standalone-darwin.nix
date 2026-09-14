# home/standalone-darwin.nix
#
# macOS 模式下的 Home Manager 入口。
# = common（便携 CLI 核心）+ 跨平台 CLI 工具 + macOS 专用 CLI 工具（home.packages）。
# 零 GUI。home.username / homeDirectory / stateVersion 由 flake 的 mkStandaloneHome 注入。
{ config, lib, pkgs, pkgs-stable, pkgs-master, inputs, ... }:

{
  imports = [
    ./common.nix
    ./nix-cn.nix
  ];

  # Token 由 bootstrap/darwin.sh 交互写入仓库外的私有文件，避免进入 Git 或 Nix store。
  nix.extraOptions = ''
    !include ${config.home.homeDirectory}/.config/nix/github-access-tokens.conf
  '';

  # macOS 保持 zsh 为默认 shell：不启用 programs.zsh、不接管 ~/.zshrc。
  # common.nix 的会话变量 / PATH 只进 HM 生成的 .bashrc；这里每次激活时幂等地向
  # ~/.zshrc 追加一段带守卫的加载（不改其余内容；不需要时删掉该段即可退出）。
  # starship 提示符与 bash 别名只影响 bash 会话，zsh 保持原生行为。
  home.activation.loadHMVarsInZsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! grep -qF 'hm-session-vars.sh' "$HOME/.zshrc" 2>/dev/null; then
      if printf '\n# Home Manager session variables (appended by nix-roam; safe to remove)\nif [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then\n  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"\nfi\n' >> "$HOME/.zshrc" 2>/dev/null; then
        echo "  ~/.zshrc: 已追加 Home Manager 会话环境加载（其余内容未改动）"
      else
        echo "  警告：无法写入 ~/.zshrc，zsh 会话将缺少 HM 环境变量" >&2
      fi
    fi
  '';

  # 跨平台 CLI 开发工具（用户级安装）
  # 平台专用包在 cli-dev.nix 内用 stdenv.hostPlatform.isDarwin 条件处理。
  home.packages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable pkgs-master;
  };
}
