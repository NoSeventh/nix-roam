# modules/desktop/gaming.nix
#
# 游戏档：Steam。32 位图形支持（Steam/Wine 的需求）归位于此；
# virtualization.nix 因 wine 另有一份同值声明（bool 同值多定义合并无冲突）。
{ ... }:

{
  programs.steam = {
    enable = true; # Master switch, already covered in installation
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
    # Other general flags if available can be set here.
  };

  # 32 位图形支持（原 profiles/desktop.nix 的 hardware.graphics.enable32Bit 归位；
  # enable 本体仍在会话栈 profiles/desktop.nix）
  hardware.graphics.enable32Bit = true;
}
