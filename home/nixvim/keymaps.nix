{ ... }:
{
  programs.nixvim = {
    # ==================== 7. 快捷键映射 ====================
    keymaps = [
      # 基础快捷键
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
        options.desc = "Clear search highlight";
      }
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<CR>";
        options.desc = "Save file";
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<CR>";
        options.desc = "Quit";
      }
      {
        mode = "n";
        key = "<leader>Q";
        action = "<cmd>qa<CR>";
        options.desc = "Quit all";
      }

      # 窗口导航
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        options.desc = "Go to left window";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        options.desc = "Go to lower window";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        options.desc = "Go to upper window";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        options.desc = "Go to right window";
      }

      # 调整窗口大小
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<CR>";
        options.desc = "Increase window height";
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<CR>";
        options.desc = "Decrease window height";
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<CR>";
        options.desc = "Decrease window width";
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<CR>";
        options.desc = "Increase window width";
      }

      # 更好的缩进
      {
        mode = "v";
        key = "<";
        action = "<gv";
        options.desc = "Decrease indent";
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
        options.desc = "Increase indent";
      }

      # 移动行
      {
        mode = "v";
        key = "J";
        action = ":m '>+1<CR>gv=gv";
        options.desc = "Move line down";
      }
      {
        mode = "v";
        key = "K";
        action = ":m '<-2<CR>gv=gv";
        options.desc = "Move line up";
      }

      # 保持光标位置
      {
        mode = "n";
        key = "J";
        action = "mzJ`z";
        options.desc = "Join lines and keep cursor";
      }
      {
        mode = "n";
        key = "<C-d>";
        action = "<C-d>zz";
        options.desc = "Scroll down and center";
      }
      {
        mode = "n";
        key = "<C-u>";
        action = "<C-u>zz";
        options.desc = "Scroll up and center";
      }
      {
        mode = "n";
        key = "n";
        action = "nzzzv";
        options.desc = "Next search result and center";
      }
      {
        mode = "n";
        key = "N";
        action = "Nzzzv";
        options.desc = "Previous search result and center";
      }

      # 系统剪贴板
      {
        mode = [ "n" "v" ];
        key = "<leader>y";
        action = ''"+y'';
        options.desc = "Yank to system clipboard";
      }
      {
        mode = "n";
        key = "<leader>Y";
        action = ''"+Y'';
        options.desc = "Yank line to system clipboard";
      }
      {
        mode = [ "n" "v" ];
        key = "<leader>d";
        action = ''"_d'';
        options.desc = "Delete without yanking";
      }

      # 快速切换缓冲区
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>bprevious<CR>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>bnext<CR>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "[b";
        action = "<cmd>bprevious<CR>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "]b";
        action = "<cmd>bnext<CR>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<CR>";
        options.desc = "Delete buffer";
      }
      {
        mode = "n";
        key = "<leader>bD";
        action = "<cmd>bdelete!<CR>";
        options.desc = "Delete buffer (force)";
      }

      # 快速跳转
      {
        mode = "n";
        key = "<leader>gg";
        action = "gg";
        options.desc = "Go to start of file";
      }
      {
        mode = "n";
        key = "<leader>G";
        action = "G";
        options.desc = "Go to end of file";
      }
    ];
  };
}
