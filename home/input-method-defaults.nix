# Shared user defaults for NixOS desktop and opt-in standalone Linux desktops.
{ ... }:

{
  xdg.configFile = {
    "fcitx5/profile".text = ''
      [Groups/0]
      Name=Default
      Default Layout=us
      DefaultIM=rime

      [Groups/0/Items/0]
      Name=keyboard-us
      Layout=

      [Groups/0/Items/1]
      Name=rime
      Layout=

      [GroupOrder]
      0=Default
    '';
    "fcitx5/config".text = ''
      [Behavior]
      ActiveByDefault=True
    '';
  };

  # Manage only the patch; compiled data and learned user dictionaries stay writable.
  # A single schema also avoids retaining a previously selected full-pinyin schema.
  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
    patch:
      __include: rime_ice_suggestion:/
      schema_list:
        - schema: double_pinyin_flypy
  '';
}
