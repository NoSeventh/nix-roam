{ pkgs-stable, ... }:
{
  programs.nixvim = {
    enable = true;
    nixpkgs.pkgs = pkgs-stable;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    # ==================== 3. 基础编辑器选项 ====================
    opts = {
      # 行号
      number = true;
      relativenumber = true;

      # 缩进
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      autoindent = true;
      smartindent = true;

      # 搜索
      ignorecase = true;
      smartcase = true;
      hlsearch = true;
      incsearch = true;

      # 外观
      termguicolors = true;
      cursorline = true;
      colorcolumn = "80";
      signcolumn = "yes";
      laststatus = 3;
      showmode = false;

      # 行为
      hidden = true;
      mouse = "a";
      clipboard = "unnamedplus";
      updatetime = 250;
      timeoutlen = 300;
      undofile = true;
      swapfile = false;
      backup = false;
      writebackup = false;

      # 折叠
      foldlevel = 99;
      foldlevelstart = 99;
      foldenable = true;

      # 滚动
      scrolloff = 4;
      sidescrolloff = 8;

      # 分割
      splitbelow = true;
      splitright = true;

      # 补全
      completeopt = [ "menu" "menuone" "noselect" ];
      pumheight = 10;

      # 换行
      wrap = false;
      linebreak = true;

      # 编码
      fileencoding = "utf-8";
      encoding = "utf-8";
    };

    # ==================== 4. 全局变量 ====================
    globals = {
      mapleader = " ";
      maplocalleader = "\\";
      have_nerd_font = true;
    };

    # ==================== 5. 自动命令 ====================
    autoCmd = [
      # 高亮复制文本
      {
        event = "TextYankPost";
        pattern = "*";
        callback = {
          __raw = ''
            function()
              vim.highlight.on_yank()
            end
          '';
        };
      }
      # 自动保存
      {
        event = [ "BufLeave" "FocusLost" ];
        pattern = "*";
        command = "silent! wall";
      }
    ];

    # ==================== 6. 主题 ====================
    colorschemes.tokyonight = {
      enable = true;
      settings = {
        style = "night";
        transparent = true;
        styles = {
          sidebars = "transparent";
          floats = "transparent";
        };
      };
    };
  };
}
