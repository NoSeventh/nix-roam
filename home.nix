{ config, pkgs, ... }:
{
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
      nv = "neovide";
    };
  };
  programs.starship = {
    #一个漂亮的shell提示符
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };
  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      vim-airline
      gruvbox
      catppuccin-vim   # 对应 catppuccin/vim
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
  xdg.configFile."~/.config/btop/btop.conf".source = ./dotfiles/.config/btop/btop.conf;
}
