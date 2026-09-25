# Lite desktop host profile (boundary decided 2026-09-26): shared session stack
# + open-source core + dev (editors/toolchains + mysql) + office (incl. texlive)
# + flatpak + browsers (chrome/edge/servo) + AI agents. Cut vs the full profile:
# media, proxy, gaming, virtualization, mnt (IHEP sshfs) and the GNOME/Plasma
# fallback DEs. A second, lighter desktop host imports this instead of
# profiles/desktop.nix; hosts/<hostname>/default.nix adds machine settings
# (boot/loader/kernel/hostname/GPU profile) and provides variables.nix + a real
# hardware-configuration.nix, then flake.nix gets the new output (the bootstrap
# --target scaffold prints the paste-ready block).
{ ... }:

{
  imports = [
    ./nixos-base.nix
    ../modules/desktop/session.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/locale-zh.nix
    ../modules/desktop/core.nix
    ../modules/desktop/flatpak.nix
    ../modules/desktop/browsers.nix
    ../modules/desktop/dev.nix
    ../modules/desktop/office.nix
    ../modules/desktop/agents.nix
  ];
}
