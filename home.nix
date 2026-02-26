{ config, pkgs, ... }:
{
  home = {
    username = "xuqihao";
    homeDirectory = "/home/xuqihao";
    stateVersion = "26.05";
  };
  programs.git = {
    enable = true;
    userName = "xuqihao";
    userEmail = "xuqihao@ihep.ac.cn";
  };
  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO 在这里添加你的自定义 bashrc 内容
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    '';

    # TODO 设置一些别名方便使用，你可以根据自己的需要进行增删
    shellAliases = {
      ll = "eza -l --icons";
      lt = "eza -lT --icons";
      la = "eza -la --icons";
      nrs = "sudo nixos-rebuild switch";
      shh = "ssh xuqihao@lxlogin.ihep.ac.cn";
      shhfs = "sshfs xuqihao@lxlogin.ihep.ac.cn:/ ~/remote/";
      afs = "cd ~/remote/afs/ihep.ac.cn/users/x/xuqihao";
      scratchfs = "cd ~/remote/scratchfs/juno/xuqihao";
      junofs = "cd ~/remote/junofs/users/xuqihao";
      workfs = "cd ~/remote/workfs2/juno/xuqihao";
      archbox = "distrobox enter archbox";
      susebox = "distrobox enter susebox";
      fedorabox = "distrobox enter fedorabox";
      kalibox = "distrobox enter kalibox";
      vi = "hx";



    #   k = "kubectl";
    #   urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
    #   urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
  };
}
