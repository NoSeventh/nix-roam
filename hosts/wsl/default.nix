# WSL boot and integration are provided by NixOS-WSL, not PC hardware config.
{ username, ... }:

{
  imports = [
    ../../profiles/nixos-base.nix
    ../../profiles/cli.nix
  ];

  networking.hostName = "wsl";
  # WSL 无真实 tty1，getty@tty1 在大版本切换时会被拉起并 start-limit 失败（switch 报 status 4）
  systemd.units."getty@tty1.service".enable = false;
  wsl = {
    enable = true;
    defaultUser = username;
  };
}
