# home/standalone-linux.nix
#
# 非 NixOS Linux 模式下的 Home Manager 入口（Linux / WSL 通用，x86_64 与 aarch64 同一模块）。
# = common（便携 CLI 核心）+ 跨平台 CLI 工具 + Linux 专用 CLI 工具（home.packages）。
# 零 GUI。home.username / homeDirectory / stateVersion 由 flake 的 mkStandaloneHome 注入。
{ config, lib, pkgs, pkgs-stable, ... }:

{
  imports = [
    ./common.nix
    ./nix-cn.nix
  ];

  # Token 由 bootstrap/linux.sh 交互写入仓库外的私有文件，避免进入 Git 或 Nix store。
  nix.extraOptions = ''
    !include ${config.home.homeDirectory}/.config/nix/github-access-tokens.conf
  '';

  # 非 bash 登录 shell 的会话环境兜底（与 darwin 入口同款思路，Linux 侧覆盖 zsh 与 fish）：
  # 不启用 programs.zsh / programs.fish、不接管 rc 文件，只在每次激活时幂等地追加带守卫的
  # 加载段（不改其余内容；不需要时删掉该段即可退出）。bash 登录链（.profile/.bash_profile）
  # 由 HM 自管，不经过这里。
  # zsh 可直接 source POSIX 语法的 hm-session-vars.sh；fish 不行 —— 装了 bass 则完整加载，
  # 否则仅把 nix profile 加入 PATH（保证工具可用；完整变量需 bash/zsh 或安装 bass）。
  home.activation.loadHMVarsInZsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! grep -qF 'hm-session-vars.sh' "$HOME/.zshrc" 2>/dev/null; then
      if printf '\n# Home Manager session variables (appended by nix-roam; safe to remove)\nif [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then\n  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"\nfi\n' >> "$HOME/.zshrc" 2>/dev/null; then
        echo "  ~/.zshrc: 已追加 Home Manager 会话环境加载（其余内容未改动）"
      else
        echo "  警告：无法写入 ~/.zshrc，zsh 会话将缺少 HM 环境变量" >&2
      fi
    fi
  '';

  # fish：仅在确实使用 fish 时才动它的配置（登录 shell 是 fish，或 config.fish 已存在），
  # 不为不存在的 fish 安装凭空创建文件。
  home.activation.loadHMVarsInFish = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    fish_in_use=0
    case "''${SHELL:-}" in
      *fish) fish_in_use=1 ;;
      *) [ -f "$FISH_CONFIG" ] && fish_in_use=1 ;;
    esac
    if [ "$fish_in_use" = "1" ] && ! grep -qF 'hm-session-vars.sh' "$FISH_CONFIG" 2>/dev/null; then
      mkdir -p "$(dirname "$FISH_CONFIG")"
      if printf '\n# Home Manager session env (appended by nix-roam; safe to remove)\nif type -q bass\n  bass source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh\nelse\n  fish_add_path -g $HOME/.nix-profile/bin\nend\n' >> "$FISH_CONFIG" 2>/dev/null; then
        echo "  $FISH_CONFIG: 已追加 Home Manager 会话环境加载（bass 缺失时仅加 PATH）"
      else
        echo "  警告：无法写入 $FISH_CONFIG，fish 会话将缺少 HM 环境" >&2
      fi
    fi
  '';

  # 共享 CLI 开发工具（用户级安装；与 NixOS 的 programs.nix 同源）
  # 平台专用包在 cli-dev.nix 内用 stdenv.hostPlatform.isLinux 条件处理。
  home.packages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable;
  };
}
