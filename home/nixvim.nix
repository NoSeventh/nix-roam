# NixVim 配置 - 提供 LazyVim 风格的体验
{ config, pkgs, pkgs-stable, ... }:

{
  # ==================== NixVim 配置 ====================
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

    # ==================== 8. 插件配置 ====================
    plugins = {
      # 命令提示
      which-key = {
        enable = true;
        settings = {
          icons = {
            breadcrumb = "»";
            group = "+";
            separator = "➜";
          };
          win = {
            border = "rounded";
            padding = [ 2 2 ];
          };
        };
      };

      # 文件浏览器
      neo-tree = {
        enable = true;
        settings = {
          sources = [ "filesystem" "buffers" "git_status" ];
          filesystem = {
            followCurrentFile = {
              enabled = true;
              leaveDirsOpen = false;
            };
            useLibuvFileWatcher = true;
          };
          window = {
            position = "left";
            width = 40;
            mappings = {
              "<space>" = "none";
            };
          };
        };
      };

      # 模糊查找
      telescope = {
        enable = true;
        settings = {
          defaults = {
            prompt_prefix = " ";
            selection_caret = " ";
            path_display = [ "smart" ];
            sorting_strategy = "ascending";
            layout_config = {
              horizontal = {
                prompt_position = "top";
                preview_width = 0.55;
              };
              vertical = {
                mirror = false;
              };
              width = 0.87;
              height = 0.80;
              preview_cutoff = 120;
            };
          };
        };
        keymaps = {
          "<leader>ff" = {
            action = "find_files";
            options.desc = "Find files";
          };
          "<leader>fg" = {
            action = "live_grep";
            options.desc = "Live grep";
          };
          "<leader>fb" = {
            action = "buffers";
            options.desc = "Find buffers";
          };
          "<leader>fh" = {
            action = "help_tags";
            options.desc = "Help tags";
          };
          "<leader>fr" = {
            action = "oldfiles";
            options.desc = "Recent files";
          };
          "<leader>fc" = {
            action = "grep_string";
            options.desc = "Find string under cursor";
          };
          "<leader>fC" = {
            action = "commands";
            options.desc = "Commands";
          };
          "<leader>fk" = {
            action = "keymaps";
            options.desc = "Keymaps";
          };
        };
      };

      # 语法高亮
      treesitter = {
        enable = true;
        settings = {
          highlight = {
            enable = true;
            additional_vim_regex_highlighting = false;
          };
          indent = {
            enable = true;
          };
          incremental_selection = {
            enable = true;
            keymaps = {
              init_selection = "<C-space>";
              node_incremental = "<C-space>";
              scope_incremental = false;
              node_decremental = "<bs>";
            };
          };
        };
        nixvimInjections = true;
      };
      treesitter-context = {
        enable = true;
        settings = {
          max_lines = 3;
        };
      };

      # LSP
      lsp = {
        enable = true;
        inlayHints = true;
        keymaps = {
          silent = true;
          lspBuf = {
            gd = {
              action = "definition";
              desc = "Go to definition";
            };
            gD = {
              action = "declaration";
              desc = "Go to declaration";
            };
            gi = {
              action = "implementation";
              desc = "Go to implementation";
            };
            gr = {
              action = "references";
              desc = "Go to references";
            };
            K = {
              action = "hover";
              desc = "Hover documentation";
            };
            "<leader>ca" = {
              action = "code_action";
              desc = "Code action";
            };
            "<leader>cr" = {
              action = "rename";
              desc = "Rename";
            };
            "<leader>cf" = {
              action = "format";
              desc = "Format";
            };
          };
          diagnostic = {
            "<leader>cd" = {
              action = "open_float";
              desc = "Line diagnostics";
            };
            "[d" = {
              action = "goto_prev";
              desc = "Previous diagnostic";
            };
            "]d" = {
              action = "goto_next";
              desc = "Next diagnostic";
            };
          };
        };
        servers = {
          # Nix
          nil_ls = {
            enable = true;
            settings = {
              formatting = {
                command = [ "nixfmt" ];
              };
            };
          };
          # Lua
          lua_ls = {
            enable = true;
            settings = {
              Lua = {
                diagnostics = {
                  globals = [ "vim" ];
                };
                workspace = {
                  library = {
                    "''\${3rd}/luv/library" = true;
                    "''\${3rd}/love2d/library" = true;
                  };
                  checkThirdParty = false;
                };
                telemetry = {
                  enable = false;
                };
              };
            };
          };
          # Python
          pyright = {
            enable = true;
          };
          # Rust
          rust_analyzer = {
            enable = true;
            installRustc = false;
            installCargo = false;
          };
          # Go
          gopls = {
            enable = true;
          };
          # TypeScript/JavaScript
          ts_ls = {
            enable = true;
          };
          # JSON
          jsonls = {
            enable = true;
          };
          # YAML
          yamlls = {
            enable = true;
          };
          # Bash
          bashls = {
            enable = true;
          };
          # C/C++
          clangd = {
            enable = true;
          };
        };
      };

      # 自动补全
      cmp = {
        enable = true;
        settings = {
          completion = {
            completeopt = "menu,menuone,noinsert";
          };
          mapping = {
            "<C-n>" = "cmp.mapping.select_next_item()";
            "<C-p>" = "cmp.mapping.select_prev_item()";
            "<C-b>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = "cmp.mapping(function(fallback)\n  if cmp.visible() then\n    cmp.select_next_item()\n  else\n    fallback()\n  end\nend, { 'i', 's' })";
            "<S-Tab>" = "cmp.mapping(function(fallback)\n  if cmp.visible() then\n    cmp.select_prev_item()\n  else\n    fallback()\n  end\nend, { 'i', 's' })";
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
          experimental = {
            ghost_text = true;
          };
        };
      };
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp_luasnip.enable = true;
      luasnip = {
        enable = true;
        fromVscode = [
          {}
        ];
      };
      friendly-snippets.enable = true;
      lspkind = {
        enable = true;
      };

      # 状态栏
      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "auto";
            globalstatus = true;
            component_separators = { left = " "; right = " "; };
            section_separators = { left = " "; right = " "; };
            disabled_filetypes = {
              statusline = [ "dashboard" "neo-tree" "alpha" ];
              winbar = [ "dashboard" "neo-tree" "alpha" ];
            };
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [ "branch" "diff" "diagnostics" ];
            lualine_c = [ "filename" ];
            lualine_x = [ "encoding" "fileformat" "filetype" ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
          inactive_sections = {
            lualine_a = [];
            lualine_b = [];
            lualine_c = [ "filename" ];
            lualine_x = [ "location" ];
            lualine_y = [];
            lualine_z = [];
          };
        };
      };

      # 缓冲区标签
      bufferline = {
        enable = true;
        settings = {
          options = {
            mode = "buffers";
            numbers = "ordinal";
            close_command = "bdelete! %d";
            right_mouse_command = "bdelete! %d";
            left_mouse_command = "buffer %d";
            middle_mouse_command = null;
            indicator = {
              style = "icon";
              icon = " ";
            };
            buffer_close_icon = " ";
            modified_icon = "●";
            close_icon = "";
            left_trunc_marker = "«";
            right_trunc_marker = "»";
            max_name_length = 18;
            max_prefix_length = 15;
            tab_size = 18;
            diagnostics = "nvim_lsp";
            diagnostics_update_in_insert = false;
            offsets = [
              {
                filetype = "neo-tree";
                text = "Explorer";
                highlight = "Directory";
                text_align = "left";
              }
            ];
            show_buffer_icons = true;
            show_buffer_close_icons = true;
            show_close_icon = true;
            show_tab_indicators = true;
            separator_style = "thin";
            enforce_regular_tabs = false;
            always_show_bufferline = true;
          };
        };
      };

      # 代码注释
      comment = {
        enable = true;
        settings = {
          opleader = {
            line = "gc";
            block = "gb";
          };
          toggler = {
            line = "gcc";
            block = "gbc";
          };
        };
      };

      # 自动括号
      nvim-autopairs = {
        enable = true;
        settings = {
          check_ts = true;
        };
      };

      # 缩进线
      indent-blankline = {
        enable = true;
        settings = {
          indent = {
            char = "│";
          };
          scope = {
            enabled = true;
          };
        };
      };

      # Git 集成
      gitsigns = {
        enable = true;
        settings = {
          signs = {
            add = { text = "+"; };
            change = { text = "~"; };
            delete = { text = "_"; };
            topdelete = { text = "‾"; };
            changedelete = { text = "~"; };
          };
          on_attach = {
            __raw = ''
              function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, l, r, opts)
                  opts = opts or {}
                  opts.buffer = bufnr
                  vim.keymap.set(mode, l, r, opts)
                end
                
                map('n', ']c', function()
                  if vim.wo.diff then return ']c' end
                  vim.schedule(function() gs.next_hunk() end)
                  return '<Ignore>'
                end, { expr = true, desc = 'Next hunk' })
                
                map('n', '[c', function()
                  if vim.wo.diff then return '[c' end
                  vim.schedule(function() gs.prev_hunk() end)
                  return '<Ignore>'
                end, { expr = true, desc = 'Previous hunk' })
                
                map('n', '<leader>gs', gs.stage_hunk, { desc = 'Stage hunk' })
                map('n', '<leader>gr', gs.reset_hunk, { desc = 'Reset hunk' })
                map('v', '<leader>gs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = 'Stage hunk' })
                map('v', '<leader>gr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = 'Reset hunk' })
                map('n', '<leader>gS', gs.stage_buffer, { desc = 'Stage buffer' })
                map('n', '<leader>gu', gs.undo_stage_hunk, { desc = 'Undo stage hunk' })
                map('n', '<leader>gR', gs.reset_buffer, { desc = 'Reset buffer' })
                map('n', '<leader>gp', gs.preview_hunk, { desc = 'Preview hunk' })
                map('n', '<leader>gb', function() gs.blame_line{full=true} end, { desc = 'Blame line' })
                map('n', '<leader>gd', gs.diffthis, { desc = 'Diff this' })
                map('n', '<leader>gD', function() gs.diffthis('~') end, { desc = 'Diff this ~' })
              end
            '';
          };
        };
      };

      # 通知
      notify = {
        enable = true;
        settings = {
          stages = "fade_in_slide_out";
          timeout = 3000;
          max_height = {
            __raw = "function()\n  return math.floor(vim.o.lines * 0.75)\nend";
          };
          max_width = {
            __raw = "function()\n  return math.floor(vim.o.columns * 0.75)\nend";
          };
          on_open = {
            __raw = "function(win)\n  vim.api.nvim_win_set_config(win, { zindex = 100 })\nend";
          };
        };
      };

      # 更好的 UI 选择器
      dressing = {
        enable = true;
      };

      # 彩虹括号
      rainbow-delimiters = {
        enable = true;
      };

      # 光标高亮
      cursorline = {
        enable = true;
      };

      # 大纲
      aerial = {
        enable = true;
        settings = {
          backends = [ "treesitter" "lsp" "markdown" "man" ];
          layout = {
            default_direction = "prefer_right";
            width = 0.2;
          };
          show_guides = true;
          filter_kind = false;
          guides = {
            mid_item = "├ ";
            last_item = "└ ";
            nested_top = "│ ";
            whitespace = "  ";
          };
          keymaps = {
            "[y" = "actions.prev";
            "]y" = "actions.next";
            "[Y" = "actions.prev_up";
            "]Y" = "actions.next_up";
          };
        };
      };

      # 待办事项高亮
      todo-comments = {
        enable = true;
        settings = {
          signs = true;
          keywords = {
            FIX = {
              icon = " ";
              color = "error";
              alt = [ "FIXME" "BUG" "FIXIT" "ISSUE" ];
            };
            TODO = {
              icon = " ";
              color = "info";
            };
            HACK = {
              icon = " ";
              color = "warning";
            };
            WARN = {
              icon = " ";
              color = "warning";
              alt = [ "WARNING" "XXX" ];
            };
            PERF = {
              icon = " ";
              color = "default";
              alt = [ "OPTIM" "PERFORMANCE" "OPTIMIZE" ];
            };
            NOTE = {
              icon = " ";
              color = "hint";
              alt = [ "INFO" ];
            };
            TEST = {
              icon = "⏲ ";
              color = "test";
              alt = [ "TESTING" "PASSED" "FAILED" ];
            };
          };
        };
      };

    };

    # ==================== 9. 额外 Lua 配置 ====================
    extraConfigLua = ''
      -- 设置透明背景（覆盖主题设置）
      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "none" })

      -- 禁用某些内置插件
      local disabled_built_ins = {
        "gzip",
        "zip",
        "zipPlugin",
        "tar",
        "tarPlugin",
        "getscript",
        "getscriptPlugin",
        "vimball",
        "vimballPlugin",
        "2html_plugin",
        "logipat",
        "rrhelper",
        "spellfile_plugin",
        "matchit"
      }

      for _, plugin in pairs(disabled_built_ins) do
        vim.g["loaded_" .. plugin] = 1
      end
    '';
  };
}
