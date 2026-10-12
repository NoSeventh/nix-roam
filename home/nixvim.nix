# NixVim entry: explicit modules grouped by editing responsibility.
{ ... }:
{
  imports = [
    ./nixvim/base.nix
    ./nixvim/keymaps.nix
    ./nixvim/navigation.nix
    ./nixvim/languages.nix
    ./nixvim/ui.nix
    ./nixvim/lua.nix
  ];
}
