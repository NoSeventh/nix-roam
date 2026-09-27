# WSL boot and integration are provided by NixOS-WSL, not PC hardware config.
{ username, ... }:

{
  imports = [
    ../../profiles/nixos-base.nix
    ../../profiles/cli.nix
  ];

  networking.hostName = "wsl";
  # WSL 无真实 tty1：getty 模板实例切换中被拉起即 SIGHUP 杀（start-limit-hit → stc exit 4）。
  # getty@tty1 与 autovt@tty1 是同一模板的两个实例名，mask 互不覆盖——9-26 事故正是只 mask 了
  # 前者、失败的是后者。stc exit 4 会让 nh（roam switch 的 NixOS 后端）跳过建系统世代（nh 先激活后设 profile），而
  # NixOS-WSL 重启从 profile 引导，不落世代即回旧系统——两个实例都 mask 才能根治。
  systemd.units."getty@tty1.service".enable = false;
  systemd.units."autovt@tty1.service".enable = false;
  # WSL 开机无登录会话，user@1000 不自启 → /run/user/1000/bus 缺失 → stc 用户单元重载
  # 失败（exit 4）→ nh 不建系统世代。linger 让用户管理器开机常驻，bus 随之就绪。
  users.users.${username}.linger = true;
  wsl = {
    enable = true;
    defaultUser = username;
  };
}
