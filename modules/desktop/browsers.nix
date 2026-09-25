# modules/desktop/browsers.nix
#
# 额外浏览器档：闭源双雄与实验性引擎。开源基座 firefox/chromium 在 core.nix
# （core 只收开源软件的约定，2026-09-26 起），故 chrome/edge 移入本档。
{
  pkgs,
  pkgs-stable,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    pkgs-stable.google-chrome
    pkgs-stable.microsoft-edge
    servo
  ];
}
