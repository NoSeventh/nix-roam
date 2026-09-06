{ config, pkgs, pkgs-stable, lib, ... }: {
  imports = [ ../../profiles/locale.nix ];

  # 输入法配置（Fcitx5）
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs-stable; [
      qt6Packages.fcitx5-chinese-addons
      qt6Packages.fcitx5-configtool

      fcitx5-gtk

      fcitx5-nord
      fcitx5-pinyin-zhwiki
      fcitx5-lua
      fcitx5-rime
      rime-ice
    ];
    fcitx5.waylandFrontend = true;
  };


  # 中文字体优化
  fonts = {
    fontDir.enable = true; # 启用旧版字体路径兼容
    packages = with pkgs-stable; [
      cascadia-code
      noto-fonts
      noto-fonts-cjk-sans    # 思源黑体
      noto-fonts-cjk-serif   # 思源宋体
      noto-fonts-color-emoji
      source-han-sans        # 思源黑体
      unifont
      dejavu_fonts
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      maple-mono.variable
      hack-font
      source-code-pro
      sarasa-gothic
      nerd-fonts.symbols-only
      font-awesome
      material-design-icons
      ark-pixel-font
      arphic-ukai
      arphic-uming
      babelstone-han
      # edusong
      # font-isas-misc
      # vista-fonts-chs
      vista-fonts-cht
      vista-fonts
      # google-fonts
      fira-code
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = [ "Noto Sans CJK SC" "DejaVu Sans" ];
        serif = [ "Noto Serif CJK SC" "DejaVu Serif" ];
        monospace = [ "Cascadia Code" "Noto Sans Mono CJK SC" ];
      };
    };
  };
}
