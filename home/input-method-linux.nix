# Optional standalone Linux desktop integration; no system services are changed.
{ config, pkgs-stable, ... }:

{
  imports = [
    ./input-method-defaults.nix
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      fcitx5-with-addons = pkgs-stable.qt6Packages.fcitx5-with-addons;
      addons = [
        (pkgs-stable.fcitx5-rime.override {
          rimeDataPkgs = [ pkgs-stable.rime-ice ];
        })
      ];
      # XDG Autostart also works on desktops without a systemd user session.
      systemd.enable = false;
    };
  };

  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".source =
    "${config.i18n.inputMethod.package}/etc/xdg/autostart/org.fcitx.Fcitx5.desktop";
}
