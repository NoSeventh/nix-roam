{ ... }:
{
  programs.nixvim.plugins = {
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

    # 文件图标
    web-devicons = {
      enable = true;
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
  };
}
