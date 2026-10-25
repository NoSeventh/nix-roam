# modules/browsers/nixos.nix
#
# 额外浏览器档：实验性引擎。开源基座 firefox/chromium 在 core.nix。
# 闭源浏览器不再进入桌面或共享可选层。
{ pkgs
, ...
}:

{
  environment.systemPackages = (import ./packages.nix { inherit pkgs; });
}
