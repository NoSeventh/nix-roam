# Full desktop host profile: shared session stack (modules/desktop/session.nix)
# plus every desktop tier. A lighter desktop host imports profiles/desktop-lite.nix
# (a decided subset) instead of this full list.
# Host-specific settings (boot, kernel, hostname, power buttons, user groups)
# belong in hosts/<hostname>/default.nix, not here.
{ ... }:

{
  imports = [
    ./nixos-base.nix
    ../modules/desktop/session.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/locale-zh.nix
    ../modules/desktop/core.nix
    ../modules/desktop/flatpak.nix
    ../modules/desktop/desktop-managers.nix
    ../modules/desktop/browsers.nix
    ../modules/desktop/dev.nix
    ../modules/desktop/media.nix
    ../modules/desktop/office.nix
    ../modules/desktop/proxy.nix
    ../modules/desktop/gaming.nix
    ../modules/desktop/agents.nix
    ../modules/desktop/mnt.nix
    ../modules/desktop/virtualization.nix
  ];
}
