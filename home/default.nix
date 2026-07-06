# home/default.nix
#
# NixOS 模式下的 Home Manager 入口（作为 home-manager.users.<user> 导入）。
# = common（便携 CLI 核心）+ GUI HM 模块（仅 NixOS 桌面）+ GUI 终端 dotfiles + 用户信息。
{ config, pkgs, pkgs-stable, inputs, ... }:

{
  imports = [
    ./common.nix
  ];

  # 用户信息（NixOS 固定）
  home = {
    username = "xuqihao";
    homeDirectory = "/home/xuqihao";
    stateVersion = "26.05";
  };

  # --- GUI 终端（仅 NixOS 桌面；非 NixOS 由原生系统负责） ---
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 12.0;
        bold = { family = "JetBrains Mono"; style = "Heavy"; };
        italic = { family = "JetBrains Mono"; style = "Medium Italic"; };
        bold_italic = { family = "JetBrains Mono"; style = "Heavy"; };
        normal = { family = "JetBrains Mono"; style = "Medium"; };
      };
      window = {
        decorations = "Full";
        dynamic_padding = false;
        opacity = 0.9;
      };
      scrolling = {
        history = 1000;
        multiplier = 5;
      };
      selection = {
        save_to_clipboard = true;
      };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight";
      background-opacity = "0.9";
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrains Mono 12";
      };
      colors = {
        background = "#000000cc";
        text = "ffffffff";
      };
    };
  };

  services.xsettingsd = {
    enable = true;
    settings = {
      "Gtk/CursorThemeName" = "Bibata-Modern-Blue";
      "Gtk/CursorThemeSize" = 24;
      "Gtk/FontName" = "JetBrains Mono 24";
      "Gtk/WindowScalingFactor" = 2;
      "Xft/Antialias" = 1;
      "Xft/Hinting" = 1;
      "Xft/HintStyle" = "hintfull";
      "Xft/RGBA" = "rgb";
      "Xft/DPI" = 196608;
    };
  };

  # --- GUI 终端 dotfiles（仅 NixOS） ---
  home.file = {
    ".config/kitty" = {
      source = ../dotfiles/.config/kitty;
      recursive = true;
    };
    ".config/wezterm" = {
      source = ../dotfiles/.config/wezterm;
      recursive = true;
    };
  };
}
