{ config, pkgs, inputs, ... }:

{
  # 导入 NixVim Home Manager 模块和 NixVim 配置
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./nixvim.nix
  ];
  home = {
    username = "xuqihao";
    homeDirectory = "/home/xuqihao";
    stateVersion = "26.05";
  };
  programs.git = {
    enable = true;
    settings = {
      user.name = "xuqihao";
      user.email = "xuqihao@ihep.ac.cn";
    };
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
      nrrs = "sudo nix-channel --update && sudo nixos-rebuild switch";
      shh = "ssh xuqihao@lxlogin.ihep.ac.cn";
      shhfs = "sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 xuqihao@lxlogin.ihep.ac.cn:/ ~/mnt/juno/";
      afs = "cd ~/mnt/juno/afs/ihep.ac.cn/users/x/xuqihao";
      scratchfs = "cd ~/mnt/juno/scratchfs/juno/xuqihao";
      junofs = "cd ~/mnt/juno/junofs/users/xuqihao";
      workfs = "cd ~/mnt/juno/workfs2/juno/xuqihao";
      archbox = "distrobox enter archbox";
      susebox = "distrobox enter susebox";
      fedorabox = "distrobox enter fedorabox";
      kalibox = "distrobox enter kalibox";
      vi = "hx";
      nv = "neovide";
      root = "root -l";
    };
  };
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 12.0;
        bold = {
          family = "JetBrains Mono";
          style = "Heavy";
        };
        italic = {
          family = "JetBrains Mono";
          style = "Medium Italic";
        };
        bold_italic = {
          family = "JetBrains Mono";
          style = "Heavy Italic";
        };
        normal = {
          family = "JetBrains Mono";
          style = "Medium";
        };
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
    # theme = tokyonight;
  };
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight";
      background-opacity = "0.9";
    };
  };
  programs.starship = {
    #一个漂亮的shell提示符
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
      # line_break.disabled = true;
    };
    presets = ["gruvbox-rainbow"];
  };
  programs.vim = {
    enable = false;  # 禁用 vim，使用 NixVim 替代
    plugins = with pkgs.vimPlugins; [
      vim-airline
      gruvbox
      catppuccin-vim # 对应 catppuccin/vim
      vim-commentary
    ];
    settings = {
      number = true;
      relativenumber = true;
      tabstop = 4;
      shiftwidth = 4;
      expandtab = true;
      ignorecase = true;
      smartcase = true;
      hidden = true;
      background = "dark";
      # 以下选项因不在支持列表中，移入 extraConfig：
      # autoindent, smartindent, cursorline, hlsearch, incsearch,
      # encoding, fileencoding, noswapfile, updatetime, termguicolors
    };
    extraConfig = ''
      " ==================== 移自 settings 的不受支持选项 ====================
      set autoindent
      set smartindent
      set cursorline
      set hlsearch
      set incsearch
      set encoding=utf-8
      set fileencoding=utf-8
      set noswapfile
      set updatetime=300

      " 条件启用真彩色（保持原逻辑）
      if has("termguicolors")
      set termguicolors
      endif

      " ==================== 原有 Vim 脚本（函数、映射等）保持不变 ====================
      let mapleader = ","
      syntax on

      " 透明背景函数
      function! s:apply_transparent_bg() abort
      highlight Normal guibg=NONE ctermbg=NONE
      highlight NonText guibg=NONE ctermbg=NONE
      highlight LineNr guibg=NONE ctermbg=NONE
      highlight Folded guibg=NONE ctermbg=NONE
      highlight EndOfBuffer guibg=NONE ctermbg=NONE
      highlight SignColumn guibg=NONE ctermbg=NONE
      highlight CursorLineNr guibg=NONE ctermbg=NONE
      highlight VertSplit guibg=NONE ctermbg=NONE
      highlight TabLineFill guibg=NONE ctermbg=NONE
      endfunction
      autocmd ColorScheme * call s:apply_transparent_bg()
      call s:apply_transparent_bg()

      " 主题切换功能
      let g:current_theme = 'catppuccin'
      function! ToggleTheme() abort
      if g:current_theme == 'catppuccin'
      let g:gruvbox_contrast_dark = 'soft'
      let g:gruvbox_italic = 1
      let g:gruvbox_transparent_bg = 1
      colorscheme gruvbox
      let g:airline_theme = 'gruvbox'
      let g:current_theme = 'gruvbox'
      echo "Theme: Gruvbox (soft dark)"
      else
      colorscheme catppuccin_mocha
      let g:current_theme = 'catppuccin'
      echo "Theme: Catppuccin Mocha"
      endif
      endfunction
      nnoremap <silent> <Leader>t :call ToggleTheme()<CR>

      " Airline 配置
      let g:airline_powerline_fonts = 1
      let g:airline#extensions#tabline#enabled = 1
      let g:airline#extensions#tabline#left_sep = ' '
      let g:airline#extensions#tabline#left_alt_sep = '|'
      let g:airline#extensions#tabline#formatter = 'unique_tail'

      if g:current_theme == 'gruvbox'
      let g:gruvbox_contrast_dark = 'soft'
      let g:gruvbox_italic = 1
      let g:gruvbox_transparent_bg = 1
      silent! colorscheme gruvbox
      let g:airline_theme = 'gruvbox'
      else
      silent! colorscheme catppuccin_mocha
      endif

      " 其他快捷键
      nnoremap <space> :nohlsearch<CR>
      nnoremap <F2> :set number! relativenumber!<CR>
      nnoremap <Leader>w :w<CR>
      nnoremap <Leader>q :q<CR>

      if has("autocmd")
      autocmd BufWritePost $MYVIMRC source $MYVIMRC
      endif
    '';
  };
  programs.helix = {
    enable = true;
    settings = {
      theme = "base16_transparent";
    };
  };
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "juno" = {
        hostname = "lxlogin.ihep.ac.cn";
        user = "xuqihao";
        port = 22;
      };
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
  # services.xsettingsd = {
  #   enable = true;
  #   settings = {
  #     "Gtk/CursorThemeName" = "Bibata-Modern-Blue";
  #     "Gtk/CursorThemeSize" = 24;
  #     "Gtk/FontName" = "JetBrains Mono 24";
  #     "Gtk/WindowScalingFactor" = 2;
  #     # "Qt/CursorThemeName" = "Bibata-Modern-Blue";
  #     # "Qt/CursorThemeSize" = 24;
  #     # "Qt/FontName" = "JetBrains Mono 24";
  #     # "Qt/WindowScalingFactor" = 2;
  #     "Xft/Antialias" = 1;
  #     "Xft/Hinting" = 1;
  #     "Xft/HintStyle" = "hintfull";
  #     "Xft/RGBA" = "rgb";
  #     "Xft/DPI" = 196608;
  #   };
  # };
  home.file = {
    ".config/btop" = {
      source = ../dotfiles/.config/btop;
      recursive = true;
    };
    # NixVim 现在通过 home/nixvim.nix 管理 Neovim 配置
    # 移除了手动链接的 .config/nvim
    # ".config/helix/config.toml" = {
    #   source = ../dotfiles/.config/helix/config.toml;
    # };
    # ".config/hypr" = {
    #   source = ../dotfiles/.config/hypr;
    #   recursive = true;
    # };
    # ".config/niri" = {
    #   source = ../dotfiles/.config/niri;
    #   recursive = true;
    # };
    ".config/kitty" = {
      source = ../dotfiles/.config/kitty;
      recursive = true;
    };
    ".config/wezterm" = {
      source = ../dotfiles/.config/wezterm;
      recursive = true;
    };
    ".config/fastfetch" = {
      source = ../dotfiles/.config/fastfetch;
      recursive = true;
    };
    # ".config/alacritty" = {
    #   source = ../dotfiles/.config/alacritty;
    #   recursive = true;
    # };
  };
}
