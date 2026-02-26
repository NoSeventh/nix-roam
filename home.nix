{ config, pkgs, ... }
{
  home = {
    users.xuqihao = {
      homeDirectory = "/home/xuqihao";
      stateVersion = "26.05";
    };
  };
}
